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
import 'package:asset_pulse_pro/features/operations/data/models/portable_tool_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:asset_pulse_pro/core/widgets/responsive_layout.dart';

/// Power Tools & Equipment (PPTE) Checklist Page
/// Uses dedicated 'power_tools' & 'power_tools_reports' Firestore collections.
/// Spacious Lux Level Header layout, accurate due date calculations,
/// 5 Industrial Machinery Functional Classes with zero layout overflows.
class PowerToolsChecklistPage extends StatefulWidget {
  const PowerToolsChecklistPage({super.key});

  @override
  State<PowerToolsChecklistPage> createState() => _PowerToolsChecklistPageState();
}

class _PowerToolsChecklistPageState extends State<PowerToolsChecklistPage> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // Navigation State
  PortableToolModel? _historyTool;
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

  // 24 Standardized Power Tools from Statutory Check Sheets
  final List<String> _equipmentTypes = [
    'Welding Machine',
    'Grinding Machine',
    'Cutting Machine',
    'Hand Drilling Machine',
    'Pedestal Drill Machine',
    'Jigsaw Machine',
    'Ply Cutter Machine',
    'Electrical Breaker',
    'Hand Blower',
    'Extension Board',
    'Floor Cleaning Machine',
    'Mixer Machine',
    'Plate Polishing Machine',
    'Fog Gun',
    'Hand Mixer',
    'Magnetic Drilling Machine',
    'Pug Machine',
    'Vibrating Machine',
    'Pedestal Fan',
    'Portable Light',
    'Portable Lighting Transformer',
    'ELC Machine',
    'Mancooler',
    'Jet Pump',
    'Other Power Tools',
  ];

  final Map<String, String> _toolShortCodes = {
    'Welding Machine': 'WM',
    'Grinding Machine': 'GM',
    'Cutting Machine': 'CM',
    'Hand Drilling Machine': 'HDM',
    'Pedestal Drill Machine': 'PDM',
    'Jigsaw Machine': 'JSM',
    'Ply Cutter Machine': 'PCM',
    'Electrical Breaker': 'EB',
    'Hand Blower': 'HB',
    'Extension Board': 'EXT',
    'Floor Cleaning Machine': 'FCM',
    'Mixer Machine': 'MXM',
    'Plate Polishing Machine': 'PPM',
    'Fog Gun': 'FG',
    'Hand Mixer': 'HMX',
    'Magnetic Drilling Machine': 'MDM',
    'Pug Machine': 'PUG',
    'Vibrating Machine': 'VM',
    'Pedestal Fan': 'PF',
    'Portable Light': 'PL',
    'Portable Lighting Transformer': 'PLT',
    'ELC Machine': 'ELC',
    'Mancooler': 'MC',
    'Jet Pump': 'JP',
    'Other Power Tools': 'OPT',
  };

  // 5 Optimized Industrial Machinery Functional Classes
  final Map<String, String> _toolEquipmentClasses = {
    'Welding Machine': 'Class 1: Welding & High-Current',
    'Plate Polishing Machine': 'Class 1: Welding & High-Current',
    'Grinding Machine': 'Class 2: High-Speed Abrasive & Cutting',
    'Cutting Machine': 'Class 2: High-Speed Abrasive & Cutting',
    'Ply Cutter Machine': 'Class 2: High-Speed Abrasive & Cutting',
    'Jigsaw Machine': 'Class 2: High-Speed Abrasive & Cutting',
    'Hand Drilling Machine': 'Class 3: Drilling, Impact & Demolition',
    'Pedestal Drill Machine': 'Class 3: Drilling, Impact & Demolition',
    'Magnetic Drilling Machine': 'Class 3: Drilling, Impact & Demolition',
    'Electrical Breaker': 'Class 3: Drilling, Impact & Demolition',
    'Pedestal Fan': 'Class 4: Air Movers, Pumps & Agitators',
    'Mancooler': 'Class 4: Air Movers, Pumps & Agitators',
    'Fog Gun': 'Class 4: Air Movers, Pumps & Agitators',
    'Hand Blower': 'Class 4: Air Movers, Pumps & Agitators',
    'Mixer Machine': 'Class 4: Air Movers, Pumps & Agitators',
    'Hand Mixer': 'Class 4: Air Movers, Pumps & Agitators',
    'Jet Pump': 'Class 4: Air Movers, Pumps & Agitators',
    'Vibrating Machine': 'Class 4: Air Movers, Pumps & Agitators',
    'Floor Cleaning Machine': 'Class 4: Air Movers, Pumps & Agitators',
    'Pug Machine': 'Class 4: Air Movers, Pumps & Agitators',
    'ELC Machine': 'Class 4: Air Movers, Pumps & Agitators',
    'Extension Board': 'Class 5: Distribution & Temp Lighting',
    'Portable Light': 'Class 5: Distribution & Temp Lighting',
    'Portable Lighting Transformer': 'Class 5: Distribution & Temp Lighting',
    'Other Power Tools': 'Class 2: High-Speed Abrasive & Cutting',
  };

  final List<String> _owners = [
    'Vedanta',
    'Monomark',
    'V.Desai',
    'Bhavana',
    'Devika',
    'Ishan Logistics',
    'Trupti',
    'Surya Transport',
  ];

  final List<String> _departments = [
    'Electrical',
    'Mechanical',
    'Civil',
    'Production',
    'Instrumentation',
    'HSE',
  ];

  // Filters
  String _selectedEqTypeChip = 'All Types';
  String _filterOwner = 'All';
  String _filterDepartment = 'All';
  String _filterEquipmentType = 'All';
  String _filterStatus = 'All';
  String _filterQuarter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Loaded Collections Data
  List<PortableToolModel> _tools = [];
  List<PortableToolChecklistReportModel> _reports = [];

  // Form State
  final _formKey = GlobalKey<FormState>();
  PortableToolModel? _selectedToolForInspection;

  final TextEditingController _testedByController = TextEditingController();
  final TextEditingController _leakageVoltageController = TextEditingController(text: '0.0');
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
    _leakageVoltageController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _generateTagCode({
    required String plant,
    required String unit,
    required String eqType,
    required String seqNo,
  }) {
    final eqCode = _toolShortCodes[eqType] ?? 'TL';
    final seqStr = seqNo.trim().isEmpty ? '001' : seqNo.trim();
    return '$plant-$unit-$eqCode-$seqStr';
  }

  String _getNextSeqNoForType(String eqType) {
    final sameTypeTools = _tools.where((t) => t.equipmentType == eqType).toList();
    int maxSeq = 0;
    for (var t in sameTypeTools) {
      final seqInt = int.tryParse(t.seqNo) ?? 0;
      if (seqInt > maxSeq) maxSeq = seqInt;
    }
    return (maxSeq + 1).toString().padLeft(3, '0');
  }

  bool _isTagIdExists(String tagId) {
    return _tools.any((t) => t.tagId.toUpperCase() == tagId.trim().toUpperCase());
  }

  String _getQuarterString(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 1 && month <= 3) return '$year-Q1';
    if (month >= 4 && month <= 6) return '$year-Q2';
    if (month >= 7 && month <= 9) return '$year-Q3';
    return '$year-Q4';
  }

  List<String> _getCheckpointsForEquipment(String eqType) {
    final lower = eqType.toLowerCase().trim();

    if (lower.contains('welding')) {
      return const [
        '1. Check incoming supply switch rating & functioning',
        '2. Check current indicator scale & visibility',
        '3. Check incoming supply cable, ensure no joints/damage & proper glanding',
        '4. Check current regulating handle functioning',
        '5. Check output cable rating, proper lugging & insulated holder',
        '6. Check overall condition (lifting hooks, wheels, body)',
        '7. Check machine identification tag number',
        '8. Check winding wire insulation & body clearance',
        '9. Check leakage voltage (body to neutral <= 50V)',
        '10. Lockout protocol: If unsafe, disconnect power & take to electrical custody',
        '11. Check machine "ON" indication lamp functioning',
        '12. Check RCCB functioning at power source (30mA)',
        '13. Check protection covers on secondary terminals',
        '14. Any other points & general safety',
      ];
    } else if (lower.contains('grind')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & industrial plug top',
        '4. Check trigger switch functioning',
        '5. Ensure wheel speed rating >= maximum tool RPM',
        '6. Ensure functional dead-man / cut-off switch',
        '7. Check grinding wheel guard covers >= 3/4 area',
        '8. Check grinding wheel without any crack or chip',
        '9. Check auxiliary handle condition (undamaged)',
        '10. Check grinding wheel nut tightness',
        '11. Check condition of machine body & casing',
        '12. Ensure body earthing in case of metal body',
        '13. Check power cable termination at entry',
        '14. Check machine identification tag number',
        '15. Any other points & general safety',
      ];
    } else if (lower.contains('cutting') || lower.contains('cut-off')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & industrial plug top',
        '4. Check trigger switch functioning',
        '5. Ensure functional dead-man / cut-off switch',
        '6. Check cutting wheel guard covers >= 3/4 area',
        '7. Check cutting wheel guard locking mechanism',
        '8. Check cutting wheel without any crack or wear',
        '9. Check handle condition (undamaged)',
        '10. Check condition of machine body & casing',
        '11. Ensure body earthing in case of metal body',
        '12. Check power cable termination at entry',
        '13. Check machine identification tag number',
        '14. Any other points & general safety',
      ];
    } else if (lower.contains('pedestal drill')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & industrial plug top',
        '4. Check trigger switch functioning',
        '5. Ensure functional dead-man / cut-off switch',
        '6. Check drill chuck & key condition',
        '7. Check handle condition (undamaged)',
        '8. Check condition of machine body & column',
        '9. Ensure body earthing in case of metal body',
        '10. Check power cable termination at entry',
        '11. Check machine identification tag number',
        '12. Check lockable push button operation',
        '13. Check ON / OFF emergency stop switch',
        '14. Check job fixing vice condition & alignment',
        '15. Any other points & general safety',
      ];
    } else if (lower.contains('magnetic drill') || lower.contains('mag drill')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Check electromagnet base holding adhesion strength',
        '6. Check drill chuck & arbor condition',
        '7. Check feed handle condition',
        '8. Check machine body condition',
        '9. Ensure body earthing in metal body',
        '10. Check power cable termination at entry',
        '11. Check machine identification tag number',
        '12. Any other points & general safety',
      ];
    } else if (lower.contains('drill')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch & reverse toggle',
        '5. Ensure functional dead-man / cut-off switch',
        '6. Check drill chuck condition & jaws',
        '7. Check auxiliary handle condition',
        '8. Check machine body & casing',
        '9. Ensure body earthing in metal body',
        '10. Check power cable termination at entry',
        '11. Check machine identification tag number',
        '12. Any other points & general safety',
      ];
    } else if (lower.contains('jigsaw') || lower.contains('jig saw')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch & speed dial',
        '5. Ensure functional dead-man switch',
        '6. Check rear handle without damage',
        '7. Check machine body condition',
        '8. Ensure body earthing in metal body',
        '9. Check power cable termination at entry',
        '10. Check machine identification tag number',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('ply cutter')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch functioning',
        '5. Ensure functional dead-man switch',
        '6. Check cutting wheel guard covers >= 3/4 area',
        '7. Check guard locking mechanism',
        '8. Check cutting wheel without crack',
        '9. Check handle condition (undamaged)',
        '10. Check machine body condition',
        '11. Ensure body earthing in metal body',
        '12. Check power cable termination at entry',
        '13. Check machine identification tag number',
        '14. Any other points & general safety',
      ];
    } else if (lower.contains('breaker') || lower.contains('demolition')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch functioning',
        '5. Ensure functional dead-man switch',
        '6. Check chisel retainer & bit locking',
        '7. Check anti-vibration handle condition',
        '8. Check machine body condition',
        '9. Ensure body earthing in metal body',
        '10. Check power cable termination at entry',
        '11. Check machine identification tag number',
        '12. Any other points & general safety',
      ];
    } else if (lower.contains('blower')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch & lock button',
        '5. Ensure functional dead-man switch',
        '6. Check rear handle & nozzle condition',
        '7. Check machine body condition',
        '8. Ensure body earthing in metal body',
        '9. Check power cable termination at entry',
        '10. Check machine identification tag number',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('extension') || lower.contains('extenstion')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure 3-core industrial cable',
        '4. Check extension board earthing continuity',
        '5. Check condition of socket outlets',
        '6. Check RCCB operation (30mA trip test)',
        '7. Check power cable gland termination',
        '8. Check identification tag number',
        '9. Check availability of socket weather caps/shutters',
        '10. Any other points & general safety',
      ];
    } else if (lower.contains('floor clean')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Check handle condition (undamaged)',
        '6. Check machine body & brush housing',
        '7. Ensure body earthing in metal body',
        '8. Check power cable termination at entry',
        '9. Check machine identification tag number',
        '10. Disconnect power before replacing debris bag',
        '11. Check capacitor & motor health',
        '12. Any other points & general safety',
      ];
    } else if (lower.contains('hand mixer')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch & speed control',
        '5. Ensure functional dead-man switch',
        '6. Check rear handle without damage',
        '7. Check machine body condition',
        '8. Ensure body earthing in metal body',
        '9. Check power cable termination at entry',
        '10. Check machine identification tag number',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('mixer')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Ensure functional dead-man switch',
        '6. Check motor double earthing continuity',
        '7. Check handle condition (undamaged)',
        '8. Check machine body condition',
        '9. Ensure body earthing in metal body',
        '10. Check power cable termination at entry',
        '11. Check machine identification tag number',
        '12. Any other points & general safety',
      ];
    } else if (lower.contains('plate polish')) {
      return const [
        '1. Check incoming supply switch rating & functioning',
        '2. Check incoming cable, ensure no joints & proper glanding',
        '3. Check RCCB operation at power source (30mA)',
        '4. Check output cable rating & insulated holder',
        '5. Ensure starter with lockable emergency stop',
        '6. Check machine identification tag number',
        '7. Check winding wire insulation & body clearance',
        '8. Check leakage voltage (body to neutral <= 50V)',
        '9. Lockout protocol: If unsafe, disconnect power',
        '10. Check machine "ON" indicator lamp',
        '11. Ensure body earthing in metal body',
        '12. Check condition of motor capacitor',
        '13. Check polishing disc balance & guard',
        '14. Any other points & general safety',
      ];
    } else if (lower.contains('fog gun') || lower.contains('fogging')) {
      return const [
        '1. Check incoming supply switch rating & functioning',
        '2. Check incoming cable, ensure no joints & proper glanding',
        '3. Check RCCB operation at power source (30mA)',
        '4. Check cable current rating & insulation',
        '5. Ensure blower fan is protected with chicken mesh',
        '6. Check machine identification tag number',
        '7. Ensure pump rotating part has 360 deg. Guarding',
        '8. Check leakage voltage (body to neutral <= 50V)',
        '9. Lockout protocol: If unsafe, disconnect power',
        '10. Check machine "ON" indicator lamp',
        '11. Ensure fog gun body double earthing',
        '12. Check plug top rating & condition',
        '13. Check tank seal & pressure relief valve',
        '14. Any other points & general safety',
      ];
    } else if (lower.contains('pug')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Check handle condition (undamaged)',
        '6. Check machine body condition',
        '7. Ensure body earthing in metal body',
        '8. Check power cable termination at entry',
        '9. Check machine identification tag number',
        '10. Check gas/air hoses condition & flash arrestor',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('vibrat')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Check machine body & needle casing',
        '6. Ensure body earthing in metal body',
        '7. Check power cable termination at entry',
        '8. Check machine identification tag number',
        '9. Any other points & general safety',
      ];
    } else if (lower.contains('pedestal fan') || lower.contains('pedestrial fan')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure fan blade is safeguarded with chicken mesh',
        '4. Check no damage to chicken mesh guard',
        '5. Ensure pedestal fan placed in stable manner',
        '6. Check switch & oscillation control',
        '7. Ensure body earthing in metal body',
        '8. Check power cable termination at entry',
        '9. Check machine identification tag number',
        '10. Lockout protocol: If unsafe, disconnect & custody',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('portable light trans') || lower.contains('lighting transformer')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Check handle condition (undamaged)',
        '4. Check transformer body condition (SELV 24V)',
        '5. Ensure body earthing in metal body',
        '6. Check power cable termination at entry',
        '7. Check machine identification tag number',
        '8. Any other points & general safety',
      ];
    } else if (lower.contains('portable light') || lower.contains('light')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Check handle condition (undamaged)',
        '4. Check light fitting body & glass cage',
        '5. Ensure body earthing in metal body',
        '6. Check power cable termination at entry',
        '7. Check machine identification tag number',
        '8. Any other points & general safety',
      ];
    } else if (lower.contains('elc')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check trigger switch functioning',
        '5. Check machine body condition',
        '6. Ensure body earthing in metal body',
        '7. Check power cable termination at entry',
        '8. Check machine identification tag number',
        '9. Check double earthing of motor',
        '10. Check all indicator lamps are glowing',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('mancooler') || lower.contains('man cooler')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure fan blade is safeguarded with chicken mesh',
        '4. Check no damage to chicken mesh guard',
        '5. Ensure mancooler placed in stable manner',
        '6. Check RCCB functioning (30mA trip)',
        '7. Ensure body earthing in metal body',
        '8. Check power cable termination at entry',
        '9. Check machine identification tag number',
        '10. Lockout protocol: If unsafe, disconnect & custody',
        '11. Any other points & general safety',
      ];
    } else if (lower.contains('jet pump') || lower.contains('pump')) {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Check machine body & pump casing',
        '6. Ensure body earthing in metal body',
        '7. Check power cable termination at entry',
        '8. Check machine identification tag number',
        '9. Check pressure gauge in good condition',
        '10. Any other points & general safety',
      ];
    } else {
      return const [
        '1. Check condition of power cable & plug top',
        '2. Ensure no cable joints or damage',
        '3. Ensure double insulated cable & plug top',
        '4. Check ON / OFF switch functioning',
        '5. Ensure functional dead-man switch',
        '6. Check handle condition (undamaged)',
        '7. Check condition of machine body',
        '8. Ensure body earthing in metal body',
        '9. Check power cable termination at entry',
        '10. Check machine identification tag number',
        '11. Any other points & general safety',
      ];
    }
  }

  void _initializeCheckpointsForEqType(String eqType) {
    final list = _getCheckpointsForEquipment(eqType);
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

  // Uses dedicated 'power_tools' and 'power_tools_reports' collections
  Future<void> _fetchData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final toolSnap = await _firestore
          .collection('power_tools')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _tools = toolSnap.docs
          .map((doc) => PortableToolModel.fromMap(doc.data(), doc.id))
          .toList();

      final now = DateTime.now();
      for (var i = 0; i < _tools.length; i++) {
        final tool = _tools[i];
        if (tool.status == 'Certified' && tool.nextDueDate != null && tool.nextDueDate!.isBefore(now)) {
          _tools[i] = PortableToolModel(
            id: tool.id,
            plantId: tool.plantId,
            unitId: tool.unitId,
            tagId: tool.tagId,
            equipmentType: tool.equipmentType,
            owner: tool.owner,
            department: tool.department,
            seqNo: tool.seqNo,
            location: tool.location,
            status: 'Expired',
            lastTestingDate: tool.lastTestingDate,
            nextDueDate: tool.nextDueDate,
            currentQuarter: tool.currentQuarter,
            remarks: tool.remarks,
            createdAt: tool.createdAt,
            updatedAt: tool.updatedAt,
          );
        }
      }

      final reportSnap = await _firestore
          .collection('power_tools_reports')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      _reports = reportSnap.docs
          .map((doc) => PortableToolChecklistReportModel.fromMap(doc.data(), doc.id))
          .toList();

      _reports.sort((a, b) => b.testingDate.compareTo(a.testingDate));
    } catch (e) {
      debugPrint('Error fetching power tool data: $e');
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

  // --- Add / Edit Master Tool Dialog ---
  void _showAddEditMasterToolDialog([PortableToolModel? existing, VoidCallback? onSuccess]) {
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    String selectedEq = existing?.equipmentType ?? _equipmentTypes.first;
    String selectedOwner = existing?.owner ?? _owners.first;
    String selectedDept = existing?.department ?? _departments.first;

    final initialSeq = isEdit ? existing.seqNo : _getNextSeqNoForType(selectedEq);
    final seqNoCtl = TextEditingController(text: initialSeq);
    final locationCtl = TextEditingController(text: existing?.location ?? '');

    String currentGeneratedId = isEdit
        ? existing.tagId
        : _generateTagCode(
            plant: _selectedPlantId!,
            unit: _selectedUnitId!,
            eqType: selectedEq,
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
                    seqNoCtl.text = _getNextSeqNoForType(selectedEq);
                  }
                  currentGeneratedId = _generateTagCode(
                    plant: _selectedPlantId!,
                    unit: _selectedUnitId!,
                    eqType: selectedEq,
                    seqNo: seqNoCtl.text,
                  );
                });
              }
            }

            final elClass = _toolEquipmentClasses[selectedEq] ?? 'Class 2: High-Speed Abrasive & Cutting';

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(isEdit ? 'Edit Tool: ${existing.tagId}' : 'Register Power Tool & Equipment'),
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
                          value: selectedEq,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Equipment Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: _equipmentTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              selectedEq = v;
                              updateTagIdAndSeq(updateSeq: true);
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        // Standard Electrical Class Indicator
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
                                child: Icon(Icons.bolt, color: Colors.blueAccent, size: 16),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Standard Category: $elClass',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedOwner,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Owner / Contractor',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    selectedOwner = v;
                                    updateTagIdAndSeq();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedDept,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Department',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    selectedDept = v;
                                    updateTagIdAndSeq();
                                  }
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
                                eqType: selectedEq,
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
                            hintText: 'e.g. Cast House Floor Bay 2',
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
                        await _firestore.collection('power_tools').doc(existing.id).update({
                          'equipmentType': selectedEq,
                          'owner': selectedOwner,
                          'department': selectedDept,
                          'location': locationCtl.text.trim(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        });
                      } else {
                        final newTool = PortableToolModel(
                          id: currentGeneratedId,
                          plantId: _selectedPlantId!,
                          unitId: _selectedUnitId!,
                          tagId: currentGeneratedId,
                          equipmentType: selectedEq,
                          owner: selectedOwner,
                          department: selectedDept,
                          seqNo: seqNoCtl.text.trim(),
                          location: locationCtl.text.trim(),
                          status: 'Never Tested',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await _firestore.collection('power_tools').doc(currentGeneratedId).set(newTool.toMap());
                      }

                      await _fetchData();
                      onSuccess?.call();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Updated Tool: $currentGeneratedId' : 'Registered Tool: $currentGeneratedId')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving tool: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: Text(isEdit ? 'Update Tool' : 'Save Tool'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTool(PortableToolModel tool) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Tool'),
        content: Text('Are you sure you want to delete tool "${tool.tagId}"? Associated inspection history will remain for audit trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isLoading = true);

              try {
                await _firestore.collection('power_tools').doc(tool.id).delete();
                await _fetchData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting tool: $e')),
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

  // --- Filter Modal Bottom Sheet ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        String tempOwner = _filterOwner;
        String tempDept = _filterDepartment;
        String tempEq = _filterEquipmentType;
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
                      const Text('Filter Power Tools & Equipment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempOwner = 'All';
                            tempDept = 'All';
                            tempEq = 'All';
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
                    value: tempOwner,
                    decoration: const InputDecoration(labelText: 'Owner / Contractor', border: OutlineInputBorder(), isDense: true),
                    items: ['All', ..._owners].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (v) => setModalState(() => tempOwner = v!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempDept,
                    decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), isDense: true),
                    items: ['All', ..._departments].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setModalState(() => tempDept = v!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: tempEq,
                    decoration: const InputDecoration(labelText: 'Equipment Type', border: OutlineInputBorder(), isDense: true),
                    items: ['All', ..._equipmentTypes].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setModalState(() => tempEq = v!),
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
                        _filterOwner = tempOwner;
                        _filterDepartment = tempDept;
                        _filterEquipmentType = tempEq;
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

  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate() || _selectedToolForInspection == null) {
      if (_selectedToolForInspection == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a master tool to perform checklist')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tool = _selectedToolForInspection!;
      final lower = tool.equipmentType.toLowerCase();
      final hasVoltageCheck = lower.contains('welding') || lower.contains('plate polish') || lower.contains('fog');
      final leakage = double.tryParse(_leakageVoltageController.text.trim()) ?? 0.0;

      bool isAllCheckpointsOk = !_checkpointStates.containsValue(false);
      bool isLeakageSafe = !hasVoltageCheck || leakage <= 50.0;

      final isCertified = isAllCheckpointsOk && isLeakageSafe;
      final statusStr = isCertified ? 'Certified' : 'Not Certified';

      final nextDue = _testDate.add(const Duration(days: 90));
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

      final reportRef = _firestore.collection('power_tools_reports').doc();
      final reportModel = PortableToolChecklistReportModel(
        id: reportRef.id,
        plantId: tool.plantId,
        unitId: tool.unitId,
        toolId: tool.id,
        tagId: tool.tagId,
        equipmentType: tool.equipmentType,
        owner: tool.owner,
        department: tool.department,
        location: tool.location,
        checkType: 'Quarterly Certification',
        testingDate: _testDate,
        nextDueDate: nextDue,
        quarter: qStr,
        status: statusStr,
        testedBy: _testedByController.text.trim().isNotEmpty ? _testedByController.text.trim() : _currentUserName,
        contractorName: tool.owner,
        leakageVoltage: hasVoltageCheck ? leakage : null,
        checkpoints: _checkpointStates,
        actionTaken: itemizedRemarks.isNotEmpty ? itemizedRemarks.join(" ; ") : 'None',
        remarks: fullRemarks,
      );

      await reportRef.set(reportModel.toMap());

      await _firestore.collection('power_tools').doc(tool.id).update({
        'status': statusStr,
        'lastTestingDate': _testDate.toIso8601String(),
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
                  ? 'Quarterly Certification SUCCESS for Tag ID: ${tool.tagId}'
                  : 'UNSAFE / NOT CERTIFIED logged for Tag ID: ${tool.tagId}. Disconnect and custody required.',
            ),
            backgroundColor: isCertified ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );

        setState(() {
          _selectedToolForInspection = null;
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

  void _startInspectionForTool(PortableToolModel tool) {
    setState(() {
      _selectedToolForInspection = tool;
      _initializeCheckpointsForEqType(tool.equipmentType);
    });
  }

  // PDF Certificate Generator
  Future<void> _exportPdfCertificate(PortableToolChecklistReportModel report) async {
    try {
      final pdf = pw.Document();
      final checkSheetTitle = '${report.equipmentType.toUpperCase()} CHECK SHEET';
      final elClass = _toolEquipmentClasses[report.equipmentType] ?? 'Class 2: High-Speed Abrasive & Cutting';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
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
                          '$checkSheetTitle - $elClass',
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
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
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                  children: [
                    pw.TableRow(children: [
                      _pdfCell('${report.equipmentType} Set No. / Tag ID:', report.tagId, isBold: true),
                      _pdfCell('Department:', report.department),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Contractor / Company Name:', report.contractorName.isNotEmpty ? report.contractorName : report.owner),
                      _pdfCell('Inspection Date:', report.testingDate.toString().split(' ')[0], isBold: true),
                    ]),
                    pw.TableRow(children: [
                      _pdfCell('Plant / Unit:', '${report.plantId} - ${report.unitId}'),
                      _pdfCell('Quarter & Next Due:', '${report.quarter} (Due: ${report.nextDueDate.toString().split(' ')[0]})'),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 12),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(26),
                    1: pw.FlexColumnWidth(5.5),
                    2: pw.FixedColumnWidth(30),
                    3: pw.FixedColumnWidth(38),
                    4: pw.FlexColumnWidth(2.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfHeaderCell('SL No.'),
                        _pdfHeaderCell('Check points'),
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
                          _pdfBodyCell(!isOk ? 'Defect noted' : ''),
                        ],
                      );
                    }),
                  ],
                ),

                if (report.leakageVoltage != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: report.leakageVoltage! <= 50 ? PdfColors.green50 : PdfColors.red50,
                      border: pw.Border.all(
                          color: report.leakageVoltage! <= 50 ? PdfColors.green400 : PdfColors.red400, width: 0.8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Measured Leakage Voltage (Body of Machine to Neutral):',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.Text('${report.leakageVoltage!.toStringAsFixed(1)} Volts (Threshold: <= 50V)',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: report.leakageVoltage! <= 50 ? PdfColors.green900 : PdfColors.red900,
                                fontSize: 8.5)),
                      ],
                    ),
                  ),
                ],

                if (report.remarks.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Remarks / Observations: ${report.remarks}',
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
                ],

                pw.Spacer(),

                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  ),
                  child: pw.Text(
                    'Equipment will be certified for use only after it is checked for above mentioned points and found to be suitable for use',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certified / Not certified: ${report.status}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(width: 140, height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 3),
                        pw.Text('Name & Signature of Certifier: ${report.testedBy}',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final fileName = 'Power_Tool_Cert_${report.tagId}_${report.quarter}.pdf';
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
                      pw.Text('Power Tools & Equipment (PPTE) Quarterly Certification Summary Audit',
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
                      _pdfHeaderCell('Unique Tag ID'),
                      _pdfHeaderCell('Equipment Type'),
                      _pdfHeaderCell('Class'),
                      _pdfHeaderCell('Owner'),
                      _pdfHeaderCell('Department'),
                      _pdfHeaderCell('Location'),
                      _pdfHeaderCell('Status'),
                      _pdfHeaderCell('Quarter'),
                      _pdfHeaderCell('Certify Date'),
                      _pdfHeaderCell('Next Due Date'),
                      _pdfHeaderCell('Certified By'),
                    ],
                  ),
                  ..._tools.map((t) {
                    final matchingReport = _reports.firstWhere(
                      (r) => r.toolId == t.id || r.tagId == t.tagId,
                      orElse: () => PortableToolChecklistReportModel(
                        id: '',
                        plantId: t.plantId,
                        unitId: t.unitId,
                        toolId: t.id,
                        tagId: t.tagId,
                        equipmentType: t.equipmentType,
                        owner: t.owner,
                        department: t.department,
                        location: t.location,
                        checkType: '',
                        testingDate: t.lastTestingDate ?? DateTime.now(),
                        nextDueDate: t.nextDueDate ?? DateTime.now(),
                        quarter: t.currentQuarter,
                        status: t.status,
                        testedBy: 'N/A',
                        contractorName: t.owner,
                        checkpoints: {},
                        remarks: '',
                      ),
                    );

                    final certDateStr = t.lastTestingDate != null ? t.lastTestingDate.toString().split(' ')[0] : 'N/A';
                    final nextDueStr = t.nextDueDate != null ? t.nextDueDate.toString().split(' ')[0] : 'N/A';
                    final testedByStr = matchingReport.testedBy.isNotEmpty ? matchingReport.testedBy : 'N/A';
                    final elClass = _toolEquipmentClasses[t.equipmentType] ?? 'Class 2';

                    return pw.TableRow(
                      children: [
                        _pdfBodyCell(t.tagId, isBold: true),
                        _pdfBodyCell(t.equipmentType),
                        _pdfBodyCell(elClass.split(':')[0]),
                        _pdfBodyCell(t.owner),
                        _pdfBodyCell(t.department),
                        _pdfBodyCell(t.location),
                        _pdfBodyCell(
                          t.status,
                          color: t.status == 'Certified'
                              ? PdfColors.green800
                              : (t.status == 'Expired' ? PdfColors.orange800 : PdfColors.red800),
                        ),
                        _pdfBodyCell(t.currentQuarter.isEmpty ? 'N/A' : t.currentQuarter),
                        _pdfBodyCell(certDateStr, isBold: true),
                        _pdfBodyCell(nextDueStr),
                        _pdfBodyCell(testedByStr),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final fileName = 'Power_Tools_Summary_${_selectedPlantId}_$_selectedUnitId.pdf';
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
      final List<Map<String, dynamic>> excelData = _tools.map((t) {
        final matchingReport = _reports.firstWhere(
          (r) => r.toolId == t.id || r.tagId == t.tagId,
          orElse: () => PortableToolChecklistReportModel(
            id: '',
            plantId: t.plantId,
            unitId: t.unitId,
            toolId: t.id,
            tagId: t.tagId,
            equipmentType: t.equipmentType,
            owner: t.owner,
            department: t.department,
            location: t.location,
            checkType: '',
            testingDate: t.lastTestingDate ?? DateTime.now(),
            nextDueDate: t.nextDueDate ?? DateTime.now(),
            quarter: t.currentQuarter,
            status: t.status,
            testedBy: 'N/A',
            contractorName: t.owner,
            checkpoints: {},
            remarks: '',
          ),
        );

        return {
          'Tag ID': t.tagId,
          'Equipment Type': t.equipmentType,
          'Class': _toolEquipmentClasses[t.equipmentType] ?? 'Class 2',
          'Owner': t.owner,
          'Department': t.department,
          'Location': t.location,
          'Status': t.status,
          'Quarter': t.currentQuarter,
          'Certify Date': t.lastTestingDate != null ? t.lastTestingDate.toString().split(' ')[0] : 'N/A',
          'Next Due Date': t.nextDueDate != null ? t.nextDueDate.toString().split(' ')[0] : 'N/A',
          'Certified By': matchingReport.testedBy,
          'Remarks': t.remarks,
        };
      }).toList();

      final fileName = 'Power_Tools_Report_${_selectedPlantId}_$_selectedUnitId.xlsx';
      final bytes = ExcelService().generateExcel(
        excelData,
        'Power Tools Registry',
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

  List<PortableToolModel> get _filteredTools {
    final query = _searchController.text.trim().toLowerCase();
    return _tools.where((tool) {
      final matchesSearch = query.isEmpty ||
          tool.tagId.toLowerCase().contains(query) ||
          tool.equipmentType.toLowerCase().contains(query) ||
          tool.owner.toLowerCase().contains(query) ||
          tool.location.toLowerCase().contains(query);

      final matchesChip = _selectedEqTypeChip == 'All Types' || tool.equipmentType == _selectedEqTypeChip;
      final matchesOwner = _filterOwner == 'All' || tool.owner == _filterOwner;
      final matchesDept = _filterDepartment == 'All' || tool.department == _filterDepartment;
      final matchesEq = _filterEquipmentType == 'All' || tool.equipmentType == _filterEquipmentType;
      final matchesStatus = _filterStatus == 'All' || tool.status == _filterStatus;
      final matchesQuarter = _filterQuarter == 'All' || tool.currentQuarter == _filterQuarter;

      return matchesSearch && matchesChip && matchesOwner && matchesDept && matchesEq && matchesStatus && matchesQuarter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Power Tools Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedToolForInspection == null && _historyTool == null && !_isManagingDatabase && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedToolForInspection != null) {
            _selectedToolForInspection = null;
          } else if (_historyTool != null) {
            _historyTool = null;
          } else if (_isManagingDatabase) {
            _isManagingDatabase = false;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Power Tools Checklist'),
        body: _selectedToolForInspection != null
            ? _buildRecordingFormView()
            : _historyTool != null
                ? _buildHistoryView()
                : _isManagingDatabase
                    ? _buildManageDatabaseView()
                    : _showHelp
                        ? _buildHelpView()
                        : _buildMainView(),
      ),
    );
  }

  // --- MAIN VIEW (Spacious Lux Level Scope Header & Metrics Overview) ---
  Widget _buildMainView() {
    final filtered = _filteredTools;
    final total = _tools.length;
    final certified = _tools.where((t) => t.status == 'Certified').length;
    final notCertified = _tools.where((t) => t.status == 'Not Certified').length;
    final expired = _tools.where((t) => t.status == 'Expired' || t.status == 'Never Tested').length;
    final compliancePct = total > 0 ? (certified / total) * 100.0 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Spacious Scope Selectors (Exact Lux Level Style)
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

          // 2. Metrics Compliance Overview Card (Spacious & Readable)
          GlassContainer(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Power Tools Safety Compliance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      _buildStatItem('Total Tools', '$total', Colors.white),
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

          // 3. Search Bar + Filter [tune] + Help [?] + Settings [gear] (Lux Level Style)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Tag ID, Equipment Type, Owner, Location...',
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
                tooltip: 'Filter Tools',
                onPressed: _showFilterModal,
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'Standards & 5 Classes Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Manage Tools Registry',
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
                ..._equipmentTypes.map((eq) => _buildTypeChip(eq)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Title & Excel / PDF Action Buttons (Matching Lux Level Style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Power Tools (${filtered.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
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

          // 5. Equipment Cards with Clear Status & "Due in X Days" / "Overdue" Calculation
          filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No matching power tools found for the selected scope.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tool = filtered[index];
                    final now = DateTime.now();
                    final isNotCert = tool.status == 'Not Certified';
                    final isCert = tool.status == 'Certified';

                    int? daysRemaining;
                    int? overdueDays;
                    if (tool.nextDueDate != null) {
                      daysRemaining = tool.nextDueDate!.difference(now).inDays;
                      if (daysRemaining < 0) {
                        overdueDays = now.difference(tool.nextDueDate!).inDays;
                      }
                    }

                    final bool isOverdue = (tool.status == 'Expired') || (daysRemaining != null && daysRemaining < 0);

                    Color statusColor = Colors.grey;
                    Color pillBg = const Color(0xFFF1F5F9);
                    IconData statusIcon = Icons.hourglass_empty;
                    String statusBadgeText = 'NEVER TESTED';
                    String dueText = 'Next Due: Immediately (Never Tested)';
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
                          ? 'Overdue by $overdueDays days (Due: ${tool.nextDueDate.toString().split(' ')[0]})'
                          : 'Overdue for Quarterly Certification';
                      dueTextColor = Colors.orangeAccent;
                    } else if (isCert) {
                      statusColor = Colors.greenAccent;
                      pillBg = Colors.green.withValues(alpha: 0.15);
                      statusIcon = Icons.check_circle;
                      statusBadgeText = 'CERTIFIED';
                      if (daysRemaining != null && daysRemaining > 0) {
                        dueText = 'Due in $daysRemaining days (${tool.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.greenAccent;
                      } else if (daysRemaining == 0) {
                        dueText = 'Due Today (${tool.nextDueDate.toString().split(' ')[0]})';
                        dueTextColor = Colors.amberAccent;
                      } else {
                        dueText = 'Next Due: ${tool.nextDueDate.toString().split(' ')[0]}';
                        dueTextColor = Colors.greenAccent;
                      }
                    }

                    final elClass = _toolEquipmentClasses[tool.equipmentType] ?? 'Class 2: High-Speed Abrasive & Cutting';

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
                                        '${tool.tagId} - ${tool.equipmentType}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Category: $elClass',
                                        style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Owner: ${tool.owner} • Dept: ${tool.department}',
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      if (tool.location.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text('Location: ${tool.location}',
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

                            // Due in X Days / Last Checked Information
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
                                    tool.currentQuarter.isNotEmpty ? 'Q: ${tool.currentQuarter}' : 'Q: N/A',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 20),

                            // Single Row Bottom Buttons with Flexible wrap protection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tool.lastTestingDate != null
                                        ? 'Last Checked: ${tool.lastTestingDate.toString().split(' ')[0]}'
                                        : 'Last Checked: Never',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history, size: 18, color: Colors.blueAccent),
                                      tooltip: 'Inspection History',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _historyTool = tool),
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
                                        isCert ? 'Retest' : 'Test Tool',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      onPressed: () => _startInspectionForTool(tool),
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
    final isSelected = _selectedEqTypeChip == label;
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
            _selectedEqTypeChip = label;
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

  // --- HISTORY VIEW (_historyTool != null) ---
  Widget _buildHistoryView() {
    final tool = _historyTool!;
    final toolReports = _reports.where((r) => r.toolId == tool.id || r.tagId == tool.tagId).toList();
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
                  onPressed: () => setState(() => _historyTool = null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audit History: ${tool.tagId}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('${tool.equipmentType} • ${tool.owner} • ${tool.department}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (toolReports.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('No quarterly inspection records found for this equipment.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: toolReports.length,
                itemBuilder: (context, index) {
                  final r = toolReports[index];
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
                                Text('Date: ${r.testingDate.toString().split(' ')[0]} | Done By: ${r.testedBy}',
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

  // --- RECORDING FORM VIEW (_selectedToolForInspection != null) ---
  Widget _buildRecordingFormView() {
    final tool = _selectedToolForInspection!;
    final lower = tool.equipmentType.toLowerCase();
    final isWeldingOrLeakageType = lower.contains('welding') || lower.contains('plate polish') || lower.contains('fog');
    final checkSheetTitle = '${tool.equipmentType.toUpperCase()} CHECK SHEET';
    final elClass = _toolEquipmentClasses[tool.equipmentType] ?? 'Class 2: High-Speed Abrasive & Cutting';

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
                        onPressed: () => setState(() => _selectedToolForInspection = null),
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
                            Text('EQUIPMENT INSPECTION DETAILS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${tool.equipmentType} Set No. / Tag ID: ${tool.tagId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('Category: $elClass',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        Text('Department: ${tool.department} | Contractor/Owner: ${tool.owner}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('Location: ${tool.location} | Plant: $_selectedPlantId - $_selectedUnitId',
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
                          decoration: const InputDecoration(labelText: 'For Quarter', border: OutlineInputBorder(), isDense: true),
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

                  TextFormField(
                    controller: _testedByController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Checklist Done By (Locked to Inspector Profile)',
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
                    final isLeakageCheck = title.toLowerCase().contains('leakage voltage');

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

                          if (isLeakageCheck && isWeldingOrLeakageType) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Inline Measurement:', style: TextStyle(fontSize: 10.5, color: Colors.orange)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _leakageVoltageController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Leakage Voltage (Threshold: <= 50V)',
                                      suffixText: 'V',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (!isOk) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _checkpointRemarks[title],
                              decoration: const InputDecoration(
                                labelText: 'Specific defect observation / reason for NOT OK',
                                hintText: 'e.g. Cable damaged, Switch sticking, Guard missing...',
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
                      'Equipment will be certified for use only after it is checked for above mentioned points and found to be suitable for use.',
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
                      _isSubmitting ? 'Saving Inspection...' : 'SUBMIT QUARTERLY CHECKLIST REPORT',
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
                    'Manage Power Tools & Equipment',
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
                    label: const Text('Add New Tool', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddEditMasterToolDialog(null, () async {
                      await _fetchData();
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
                            collectionId: 'power_tools',
                            title: 'Power Tools Import',
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
            _tools.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No tools found. Add one above!')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tools.length,
                    itemBuilder: (context, idx) {
                      final tool = _tools[idx];
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
                                        Text(tool.tagId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 3),
                                        Text('${tool.equipmentType} • Owner: ${tool.owner} • Dept: ${tool.department}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        if (tool.location.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text('Location: ${tool.location}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                                        tooltip: 'Edit Tool',
                                        onPressed: () => _showAddEditMasterToolDialog(tool, () async {
                                          await _fetchData();
                                          setState(() {});
                                        }),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete Tool',
                                        onPressed: () => _confirmDeleteTool(tool),
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

  // --- HELP VIEW (5 Equipment Classes with zero layout overflow) ---
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
                    'Power Tools Safety Standards & 5 Equipment Classes',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Card 1: The 5 Equipment Classes & Standard Checkpoints
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
                        Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '1. The 5 Equipment Classes & Standard Checkpoints',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildClassItem(
                      'Class 1: Welding & High-Current Equipment',
                      'HEAVY MACHINERY',
                      Colors.greenAccent,
                      '• Tools: Welding Machine, Plate Polishing Machine\n'
                      '• Core Checks: Supply cable without joints/damage, proper cable glanding, current regulator scale visibility, secondary terminal protection covers, insulated electrode holder, lifting hooks & wheels.\n'
                      '• Electrical Verification: Leakage Voltage <= 50V (Body to Neutral), VRD (Voltage Reduction Device) Idle OCV <= 30V, source 30mA RCCB.\n'
                      '• Fail Protocol: Immediate power disconnect & electrical custody lockout.',
                    ),
                    const SizedBox(height: 10),

                    _buildClassItem(
                      'Class 2: High-Speed Abrasive & Cutting Machinery',
                      'PORTABLE ROTARY CUTTERS',
                      Colors.cyanAccent,
                      '• Tools: Grinding Machine, Cutting Machine, Ply Cutter Machine, Jigsaw Machine\n'
                      '• Core Checks: Wheel guard securely locked & covering >= 3/4 area, wheel without cracks/chips, blade speed rating >= maximum tool RPM, spindle nut tightness.\n'
                      '• Switch & Control: Spring-loaded dead-man / cut-off trigger switch (automatic power cut upon grip release).\n'
                      '• Insulation: Class II double-insulated cable & industrial molded 3-pin plug top.',
                    ),
                    const SizedBox(height: 10),

                    _buildClassItem(
                      'Class 3: Drilling, Impact & Demolition Tools',
                      'DRILLING & IMPACT',
                      Colors.purpleAccent,
                      '• Tools: Hand Drilling Machine, Pedestal Drill Machine, Magnetic Drilling Machine, Electrical Breaker\n'
                      '• Core Checks: Drill chuck condition & jaws, chisel bit locking & retainer, handle integrity, job-fixing vice & column alignment (pedestal drill), electromagnetic base adhesion strength (magnetic drill).\n'
                      '• Controls: Lockable push button, emergency stop switch, functional ON/OFF selector switch.',
                    ),
                    const SizedBox(height: 10),

                    _buildClassItem(
                      'Class 4: Industrial Air Movers, Pumps & Agitators',
                      'FANS & ROTATING PUMPS',
                      Colors.blueAccent,
                      '• Tools: Pedestal Fan, Mancooler, Fog Gun, Hand Blower, Mixer Machine, Hand Mixer, Jet Pump, Vibrating Machine, Floor Cleaning Machine, Pug Machine, ELC Machine\n'
                      '• Core Checks: Protective chicken mesh safeguarding on fan blades & rotating parts (360° guarding on pumps), pressure gauge calibration (jet pump), capacitor health.\n'
                      '• Electrical: Motor double earthing continuity, IP54/IP55 weatherproofing on outdoor units.',
                    ),
                    const SizedBox(height: 10),

                    _buildClassItem(
                      'Class 5: Portable Power Distribution & Temporary Lighting',
                      'DISTRIBUTION & SELV',
                      Colors.amberAccent,
                      '• Tools: Extension Board, Portable Light, Portable Lighting Transformer\n'
                      '• Core Checks: 3-core heavy-duty rubber cable, continuous earth pin grounding, socket safety shutters/caps, RCCB push-to-test button (30mA).\n'
                      '• Transformer Safety: Step-down to SELV 24V / 110V center-tapped earth (CTE 55V) for confined space inspections.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: Statutory Norms & Limits Summary Table
            GlassContainer(
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('2. Statutory Limits & Acceptance Criteria',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                    SizedBox(height: 8),
                    Text(
                      '• Leakage Voltage (Max 50V): Measured voltage between machine metal body and neutral must not exceed 50 Volts (Welding Machine, Plate Polishing Machine, Fog Gun).\n'
                      '• VRD Open Circuit Voltage (Max 30V): Voltage reduction devices must maintain idle OCV <= 30V.\n'
                      '• RCCB Sensitivity: 30mA residual current circuit breakers must trip within <= 300ms at the source.\n'
                      '• Wheel Guarding (3/4 Coverage): Protective guards must securely cover minimum 3/4 area of abrasive wheels (Factories Act 1948 Sec 21 & OSHA 1926.300).\n'
                      '• Dead-Man Trigger: Spring-loaded trigger must immediately disconnect power when operator grip is released.\n'
                      '• Safeguarding Chicken Mesh: Pedestal fans, Mancoolers, and Fog guns must have protective mesh enclosing fan blades & rotating parts.\n'
                      '• Double Insulation: Flexible supply cords must be double insulated without joints and terminated in 3-pin industrial plug tops.\n'
                      '• Unsafe Custody Lockout: If any tool fails certification, power cable must be immediately disconnected and tagged in electrical custody.',
                      style: TextStyle(fontSize: 11.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Card 3: 3-Letter Standard Equipment Short Codes
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
                      children: _toolShortCodes.entries.map((e) {
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

            // Card 4: Expandable Checklist Questions Directory for ALL 24 Machines
            const Text('4. Statutory Check Questions Directory for All 24 Machines',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _equipmentTypes.length,
              itemBuilder: (context, idx) {
                final eq = _equipmentTypes[idx];
                final code = _toolShortCodes[eq] ?? 'TL';
                final elClass = _toolEquipmentClasses[eq] ?? 'Class 2';
                final questions = _getCheckpointsForEquipment(eq);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: Text(
                      '[$code] $eq (${questions.length} Points)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    subtitle: Text('Category: $elClass', style: const TextStyle(fontSize: 10.5, color: Colors.tealAccent)),
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

  Widget _buildClassItem(String title, String badge, Color color, String description) {
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
