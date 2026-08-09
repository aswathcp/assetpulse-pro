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
import 'package:uuid/uuid.dart';

// PDF, Excel & Import Pages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:asset_pulse_pro/core/services/excel_service.dart';
import 'package:asset_pulse_pro/core/utils/file_download_helper.dart';
import 'package:asset_pulse_pro/features/operations/data/models/lux_level_report_model.dart';
import 'package:asset_pulse_pro/features/admin/presentation/pages/data_import_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

// Comprehensive IS 3646 (Part 1) : 2025 Categories & Area Types Library for Vedanta Iron & Steel Ltd
const Map<String, List<Map<String, dynamic>>> luxCategories = {
  'Category 1: Iron & Steel Production / Process Bays': [
    {
      'type': 'Blast Furnace Cast House Floor',
      'tableRef': 'IS 3646 Table 30.2',
      'lowLux': 100,
      'midLux': 150,
      'highLux': 200,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 28,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Blast Furnace cast house floor and metal tapping areas.',
    },
    {
      'type': 'Pig Casting Machine (PCM) Floor',
      'tableRef': 'IS 3646 Table 30.3',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Pig Casting Machine (PCM) floor and metal pouring zones.',
    },
    {
      'type': 'Furnaces & Cupola Stations',
      'tableRef': 'IS 3646 Table 30.5',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 25,
      'plane': 'Platform level',
      'desc': 'Furnace operating platforms, cupolas, and ladle heating stations.',
    },
    {
      'type': 'Mill Train / Coiler / Shear Line',
      'tableRef': 'IS 3646 Table 30.6',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.60,
      'ra': 70,
      'rugl': 25,
      'plane': 'Equipment height',
      'desc': 'Rolling mill train, hot coilers, and flying shear lines.',
    },
    {
      'type': 'Control Platforms & Local Panels',
      'tableRef': 'IS 3646 Table 30.7',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 22,
      'plane': 'Panel face (0.8 m)',
      'desc': 'Local control platforms, desk panels, and operator push-button stations.',
    },
    {
      'type': 'Foundry Casting & Shakeout Bay',
      'tableRef': 'IS 3646 Table 21.6',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Foundry moulding floor, shakeout bay, and slag removal areas.',
    },
    {
      'type': 'Hand & Core Moulding / Die Casting',
      'tableRef': 'IS 3646 Table 21.9',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 25,
      'plane': 'Work height',
      'desc': 'Manual core moulding, sand preparation, and die casting machines.',
    },
    {
      'type': 'Slab Store / Billet Yard',
      'tableRef': 'IS 3646 Table 30.4',
      'lowLux': 30,
      'midLux': 50,
      'highLux': 75,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 0,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Slab storage bays, billet yards, and heavy metal storage grounds.',
    },
  ],
  'Category 2: Control Rooms & Command Centers': [
    {
      'type': 'Main Control Room / SCADA Desks',
      'tableRef': 'IS 3646 Table 11.2',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 19,
      'plane': 'Desk level (0.8 m)',
      'desc': 'Main plant control rooms, SCADA desks, and continuous monitoring work.',
    },
    {
      'type': 'Surveillance / CCTV Desk',
      'tableRef': 'IS 3646 Table 11.3',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 19,
      'plane': 'Desk level (0.8 m)',
      'desc': 'Plant security surveillance desks, monitor banks, and operator stations.',
    },
    {
      'type': 'Testing, Sampling & Metal Quality Lab',
      'tableRef': 'IS 3646 Table 30.8',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 22,
      'plane': 'Bench level (0.8 m)',
      'desc': 'Metallurgical testing benches, chemical analysis, sample preparation, and precision testing.',
    },
  ],
  'Category 3: Electrical Infrastructure': [
    {
      'type': 'Substation / Switchgear Rooms',
      'tableRef': 'IS 3646 Table 11.1',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Panel face / Floor',
      'desc': 'Substations, HT/LT switchgear rooms, breaker panels, and transformer bays.',
    },
    {
      'type': 'MCC & Electrical Panel Rooms',
      'tableRef': 'IS 3646 Table 28.4',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Panel face (0.8 m)',
      'desc': 'Motor Control Center (MCC) rooms, PLC panels, and distribution boards.',
    },
    {
      'type': 'Battery Rooms / Charger Areas',
      'tableRef': 'IS 3646 Table 28.4',
      'lowLux': 100,
      'midLux': 150,
      'highLux': 200,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'DC battery charger panels, battery banks, and hazardous acid storage inspection.',
    },
  ],
  'Category 4: Mechanical Utilities & Captive Power Plant': [
    {
      'type': 'Pump Houses / Compressor Rooms',
      'tableRef': 'IS 3646 Table 28.4',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Auxiliary pump houses, air compressor stations, and water treatment plants.',
    },
    {
      'type': 'Boiler House Floor / Piping Bay',
      'tableRef': 'IS 3646 Table 28.2',
      'lowLux': 75,
      'midLux': 100,
      'highLux': 150,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 28,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Captive power plant boiler structures, burner floors, and steam piping galleries.',
    },
    {
      'type': 'Turbine / Generator Machine Hall',
      'tableRef': 'IS 3646 Table 28.3',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Operating floor',
      'desc': 'Turbine generator floors, condenser basements, and auxiliary machine halls.',
    },
    {
      'type': 'Fuel / Coal Supply Handling',
      'tableRef': 'IS 3646 Table 28.1',
      'lowLux': 30,
      'midLux': 50,
      'highLux': 75,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 0,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Coal handling plant, crusher house, fuel unloading, and conveyor hoppers.',
    },
  ],
  'Category 5: Storage, Warehousing & Raw Materials': [
    {
      'type': 'Covered Raw Material Sheds',
      'tableRef': 'IS 3646 Table 13.4',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Covered raw material storage sheds, warehouses, stockrooms, and loader movement bays.',
    },
    {
      'type': 'Store & Spare Parts Stockroom',
      'tableRef': 'IS 3646 Table 12.1',
      'lowLux': 75,
      'midLux': 100,
      'highLux': 150,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor / Rack face',
      'desc': 'Central store rooms, mechanical/electrical spare parts racks, and tool cribs.',
    },
    {
      'type': 'Dispatch & Packing Area',
      'tableRef': 'IS 3646 Table 12.2',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 25,
      'plane': 'Table level (0.8 m)',
      'desc': 'Dispatch packing tables, material bundling, and shipping inspection desks.',
    },
    {
      'type': 'Open Storage Yards / Slag Pits',
      'tableRef': 'IS 3646 Table 42.3',
      'lowLux': 30,
      'midLux': 50,
      'highLux': 75,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 25,
      'plane': 'Ground level',
      'desc': 'Open perimeter yards, slag cooling pits, coal yards, and plant transport roads.',
    },
  ],
  'Category 6: Transit, Conveyors & Basements': [
    {
      'type': 'Conveyor Belt Galleries / Walkways',
      'tableRef': 'IS 3646 Table 9.1',
      'lowLux': 75,
      'midLux': 100,
      'highLux': 150,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 28,
      'plane': 'Walkway floor',
      'desc': 'Elevated conveyor galleries, transfer towers, pedestrian gangways, and walkways.',
    },
    {
      'type': 'Plant Staircases & Escalators',
      'tableRef': 'IS 3646 Table 9.2',
      'lowLux': 75,
      'midLux': 100,
      'highLux': 150,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 25,
      'plane': 'Stair tread',
      'desc': 'Plant structure staircases, emergency escape ladders, and platform steps.',
    },
    {
      'type': 'Underfloor Cable Tunnels & Cellars',
      'tableRef': 'IS 3646 Table 30.9',
      'lowLux': 30,
      'midLux': 50,
      'highLux': 75,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 0,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Underfloor cable cellars, man-sized tunnels, and basement pipe corridors.',
    },
    {
      'type': 'Elevators & Lift Lobbies',
      'tableRef': 'IS 3646 Table 9.3',
      'lowLux': 75,
      'midLux': 100,
      'highLux': 150,
      'uniformity': 0.40,
      'ra': 70,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Goods lifts, passenger elevator cabins, and elevator landing areas.',
    },
  ],
  'Category 7: General Offices & Administrative Areas': [
    {
      'type': 'General Office (Writing / PC Work)',
      'tableRef': 'IS 3646 Table 34.2',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 19,
      'plane': 'Desk level (0.8 m)',
      'desc': 'Plant administrative offices, open plan workspaces, and data entry desks.',
    },
    {
      'type': 'Private Cabins & CAD Workstations',
      'tableRef': 'IS 3646 Table 34.3',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.70,
      'ra': 80,
      'rugl': 19,
      'plane': 'Desk level (0.8 m)',
      'desc': 'Manager cabins, engineering CAD drafting desks, and design rooms.',
    },
    {
      'type': 'Conference & Meeting Rooms',
      'tableRef': 'IS 3646 Table 34.6',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.60,
      'ra': 80,
      'rugl': 19,
      'plane': 'Table level (0.8 m)',
      'desc': 'Meeting rooms, conference halls, and plant briefing rooms.',
    },
    {
      'type': 'Filing & Archiving Rooms',
      'tableRef': 'IS 3646 Table 34.1',
      'lowLux': 200,
      'midLux': 300,
      'highLux': 500,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 19,
      'plane': 'Shelf face / Floor',
      'desc': 'Document record rooms, document archives, and active filing areas.',
    },
  ],
  'Category 8: Welfare, Canteen & Medical Facilities': [
    {
      'type': 'Plant Canteen & Dining Hall',
      'tableRef': 'IS 3646 Table 10.1',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 22,
      'plane': 'Table level (0.8 m)',
      'desc': 'Plant canteen dining halls, break areas, and refreshment counters.',
    },
    {
      'type': 'Washrooms, Toilets & Lockers',
      'tableRef': 'IS 3646 Table 10.4',
      'lowLux': 150,
      'midLux': 200,
      'highLux': 300,
      'uniformity': 0.40,
      'ra': 80,
      'rugl': 25,
      'plane': 'Floor level (0.0 m)',
      'desc': 'Worker change rooms, locker rooms, washrooms, and sanitation facilities.',
    },
    {
      'type': 'Occupational Health / First Aid Room',
      'tableRef': 'IS 3646 Table 10.7',
      'lowLux': 300,
      'midLux': 500,
      'highLux': 750,
      'uniformity': 0.60,
      'ra': 90,
      'rugl': 19,
      'plane': 'Bed / Table level',
      'desc': 'Plant first aid room, occupational health center, and medical examination rooms.',
    },
  ],
};

// Helper to lookup sub-type details
Map<String, dynamic> getDetailsForType(String typeName) {
  for (final category in luxCategories.values) {
    for (final item in category) {
      if (item['type'] == typeName) {
        return item;
      }
    }
  }
  return {
    'type': typeName,
    'tableRef': 'IS 3646 Table 30.2',
    'lowLux': 100,
    'midLux': 150,
    'highLux': 200,
    'uniformity': 0.40,
    'ra': 70,
    'rugl': 28,
    'plane': 'Floor level (0.0 m)',
    'desc': 'Standard industrial plant space.',
  };
}

// Helper to lookup category for sub-type
String getCategoryForType(String typeName) {
  for (final entry in luxCategories.entries) {
    for (final item in entry.value) {
      if (item['type'] == typeName) {
        return entry.key;
      }
    }
  }
  return luxCategories.keys.first;
}

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

class LuxLevelChecklistPage extends StatefulWidget {
  const LuxLevelChecklistPage({super.key});

  @override
  State<LuxLevelChecklistPage> createState() => _LuxLevelChecklistPageState();
}

class _LuxLevelChecklistPageState extends State<LuxLevelChecklistPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Scope State
  String? _selectedBusinessId;
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
  String _currentUserName = 'Operator';

  // Data & Filter State
  List<Map<String, dynamic>> _locations = [];
  List<LuxLevelReportModel> _reports = [];
  List<Map<String, dynamic>> _processedLocations = [];
  final TextEditingController _searchController = TextEditingController();

  // Navigation State
  Map<String, dynamic>? _selectedLocation;
  String? _editingReportId;
  Map<String, dynamic>? _historyLocation;
  bool _isManagingLocations = false;
  bool _showHelp = false;

  // Recording Form State
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _gridControllers = List.generate(9, (_) => TextEditingController());
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  String _checkType = 'Routine';
  DateTime _testDate = DateTime.now();

  // Visual Inspection Checkpoints (No meter required)
  bool _isLuminaireClean = true;
  bool _isGlareShielded = true;
  bool _isFlickerFree = true;

  double _averageLux = 0.0;
  double _uniformityRatio = 0.0;
  String _status = 'Fail';
  String _rangeTag = 'Below Standard';
  bool _isSubmitting = false;

  // Quick Corrective Action Presets for Retest Workflow
  final List<String> _actionPlanPresets = [
    'New LED Luminaires Installed',
    'Burnt / Degraded Lamps Replaced',
    'Optics & Covers Cleaned / De-dusted',
    'Anti-Glare Louver / Shield Fitted',
    'Ballast & Wiring Terminal Repaired',
  ];

  // Analytics Metrics
  int _totalLocations = 0;
  int _compliantCount = 0;
  int _lowLuxCount = 0;
  int _overdueCount = 0;
  double _complianceRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadScopeAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _gridControllers) {
      controller.dispose();
    }
    _remarksController.dispose();
    _actionTakenController.dispose();
    super.dispose();
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
        _currentUserName = profile['displayName'] ?? profile['name'] ?? 'Operator';
        final userBusinessId = profile['businessId'] as String? ?? 'VISL';

        await HierarchyService().init(businessId: userBusinessId);
        _selectedBusinessId = HierarchyService().currentBusinessId;
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

    await _loadData();
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

  Future<void> _loadData() async {
    if (_selectedPlantId == null || _selectedUnitId == null) return;

    try {
      final locSnapshot = await _firestore
          .collection('lux_locations')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final locs = locSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      locs.sort((a, b) => compareNatural(a['id'].toString(), b['id'].toString()));

      final reportSnapshot = await _firestore
          .collection('lux_level_reports')
          .where('plantId', isEqualTo: _selectedPlantId)
          .where('unitId', isEqualTo: _selectedUnitId)
          .get();

      final reps = reportSnapshot.docs
          .where((doc) => doc.data()['deleted'] != true)
          .map((doc) => LuxLevelReportModel.fromMap(doc.data(), doc.id))
          .toList();

      _locations = locs;
      _reports = reps;

      _processComplianceData();
    } catch (e) {
      debugPrint('Error loading Lux Level data: $e');
    }
  }

  void _processComplianceData() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 180));
    final List<Map<String, dynamic>> processed = [];

    int compliant = 0;
    int lowLux = 0;
    int overdue = 0;

    for (final loc in _locations) {
      final locId = loc['id'];
      final locReports = _reports.where((r) => r.locationId == locId).toList();
      locReports.sort((a, b) => b.testingDate.compareTo(a.testingDate));

      final latestReport = locReports.isNotEmpty ? locReports.first : null;
      String status = 'Never Tested';
      DateTime? lastTestedDate = latestReport?.testingDate;
      int? lastMeasuredVal = latestReport?.measuredLux;

      if (latestReport == null) {
        status = 'Never Tested';
        overdue++;
      } else {
        final isOverdue = lastTestedDate!.isBefore(cutoffDate);
        final details = getDetailsForType(loc['type'] ?? '');
        final int lowLuxStd = details['lowLux'] as int? ?? 100;
        final double targetUniformity = details['uniformity'] as double? ?? 0.40;
        final bool meetsMinStd = (latestReport.averageLux >= lowLuxStd) && (latestReport.uniformityRatio >= targetUniformity);
        if (isOverdue) {
          status = 'Overdue';
          overdue++;
        } else if (!meetsMinStd) {
          status = 'Low Lux';
          lowLux++;
        } else {
          status = 'Compliant';
          compliant++;
        }
      }

      processed.add({
        ...loc,
        'status': status,
        'lastTested': lastTestedDate,
        'lastMeasured': lastMeasuredVal,
        'latestReport': latestReport,
        'history': locReports,
      });
    }

    setState(() {
      _processedLocations = processed;
      _totalLocations = _locations.length;
      _compliantCount = compliant;
      _lowLuxCount = lowLux;
      _overdueCount = overdue;
      _complianceRate = _totalLocations == 0 ? 0.0 : (compliant / _totalLocations) * 100.0;

      if (_historyLocation != null) {
        _historyLocation = _processedLocations.firstWhere(
          (element) => element['id'] == _historyLocation!['id'],
          orElse: () => _historyLocation!,
        );
      }
    });
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$min $ampm";
  }

  bool _canEditOrDeleteReport(DateTime testingDate, String testedBy) {
    if (_isAdmin) return true;
    final diff = DateTime.now().difference(testingDate);
    final isTester = testedBy.toLowerCase() == _currentUserName.toLowerCase();
    return isTester && diff.inHours < 8;
  }

  void _confirmDeleteReport(String reportId, Map<String, dynamic> loc) {
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
              await _firestore.collection('lux_level_reports').doc(reportId).update({
                'deleted': true,
                'deletedBy': _currentUserName,
                'deletedAt': DateTime.now().toIso8601String(),
              });
              Navigator.pop(context);
              await _loadData();
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Sub-Dialog for Adding/Editing Lux Locations with Category Dropdowns ---
  void _showAddEditLocationDialog(Map<String, dynamic>? existing, VoidCallback onSaved) {
    final formKey = GlobalKey<FormState>();
    final nameCtl = TextEditingController(text: existing?['name']);

    String suggestedNumber = '';
    if (existing == null) {
      int maxIdx = 0;
      for (var loc in _locations) {
        final stripped = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
        if (stripped.startsWith('LUX-')) {
          final numPart = int.tryParse(stripped.substring(4));
          if (numPart != null && numPart > maxIdx) {
            maxIdx = numPart;
          }
        }
      }
      suggestedNumber = '${maxIdx + 1}';
    } else {
      final stripped = HierarchyService.stripPrefix(existing['id'], _selectedPlantId!, _selectedUnitId!);
      if (stripped.startsWith('LUX-')) {
        suggestedNumber = stripped.substring(4);
      } else {
        suggestedNumber = stripped;
      }
    }

    final idCtl = TextEditingController(text: suggestedNumber);
    String selectedType = existing?['type'] ?? luxCategories.values.first.first['type'] as String;
    String selectedCategory = existing?['category'] ?? getCategoryForType(selectedType);
    String selectedOrientation = existing?['compassOrientation'] ?? 'North-Up';
    final List<String> orientations = ['North-Up', 'East-Up', 'South-Up', 'West-Up'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentCategoryTypes = luxCategories[selectedCategory] ?? [];
            final currentDetails = getDetailsForType(selectedType);

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(existing == null ? 'Add Lux Location' : 'Edit Lux Location'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: idCtl,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            prefixText: 'LUX-',
                            prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            labelText: 'Location ID Number',
                            hintText: 'e.g. 1',
                            border: OutlineInputBorder(),
                            helperText: 'Saved as: PLANT-UNIT-LUX-[Number]',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.contains('-') || v.toUpperCase().contains('LUX')) {
                              return 'Input sequence only (e.g. 1, 2, 5B)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtl,
                          decoration: const InputDecoration(
                            labelText: 'Area / Room Name',
                            hintText: 'e.g. BF1 Cast House Floor',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'IS 3646 Area Category',
                            border: OutlineInputBorder(),
                          ),
                          items: luxCategories.keys.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() {
                                selectedCategory = v;
                                final newTypes = luxCategories[selectedCategory] ?? [];
                                if (newTypes.isNotEmpty) {
                                  selectedType = newTypes.first['type'] as String;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Sub-Type Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Specific Area Type',
                            border: OutlineInputBorder(),
                          ),
                          items: currentCategoryTypes.map((item) {
                            final type = item['type'] as String;
                            final lux = item['midLux'] as int;
                            return DropdownMenuItem(
                              value: type,
                              child: Text('$type ($lux Lux)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedType = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Details Summary Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentDetails['tableRef']}: Standard Scale ${currentDetails['lowLux']} - ${currentDetails['midLux']} - ${currentDetails['highLux']} Lux',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                              ),
                              const SizedBox(height: 4),
                              Text('Min Uniformity (Uo): >= ${currentDetails['uniformity']} | CRI (Ra): >= ${currentDetails['ra']} | Glare: <= ${currentDetails['rugl']}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              Text('Plane: ${currentDetails['plane']}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(currentDetails['desc'] ?? '', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: selectedOrientation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Fixed Compass Orientation Reference',
                            border: OutlineInputBorder(),
                            helperText: 'Locks spatial points for future retests',
                          ),
                          items: orientations.map((o) {
                            return DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedOrientation = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final rawId = 'LUX-${idCtl.text.trim()}';
                      final fullDocId = HierarchyService.prefixId(rawId, _selectedPlantId!, _selectedUnitId!);
                      final details = getDetailsForType(selectedType);

                      final data = {
                        'id': fullDocId,
                        'name': nameCtl.text.trim(),
                        'type': selectedType,
                        'category': selectedCategory,
                        'tableRef': details['tableRef'],
                        'lowLux': details['lowLux'],
                        'midLux': details['midLux'],
                        'highLux': details['highLux'],
                        'uniformity': details['uniformity'],
                        'ra': details['ra'],
                        'rugl': details['rugl'],
                        'plane': details['plane'],
                        'compassOrientation': selectedOrientation,
                        'plantId': _selectedPlantId,
                        'unitId': _selectedUnitId,
                        'businessId': _selectedBusinessId,
                      };

                      await _firestore.collection('lux_locations').doc(fullDocId).set(data, SetOptions(merge: true));
                      if (context.mounted) Navigator.pop(context);
                      onSaved();
                    }
                  },
                  child: const Text('Save Location'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLocation(Map<String, dynamic> loc, VoidCallback onDeleted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "${loc['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _firestore.collection('lux_locations').doc(loc['id']).delete();
              if (context.mounted) Navigator.pop(context);
              onDeleted();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Trigger fresh record / retest or retrospect editing ---
  void _startRecordOrEdit(Map<String, dynamic> loc, LuxLevelReportModel? existingReport) {
    setState(() {
      _selectedLocation = loc;
      _editingReportId = existingReport?.id;
      _checkType = existingReport?.checkType ?? (loc['status'] == 'Low Lux' || loc['status'] == 'Overdue' ? 'Retest' : 'Routine');
      _testDate = existingReport?.testingDate ?? DateTime.now();
      _remarksController.text = existingReport?.remarks ?? '';
      _actionTakenController.text = existingReport?.actionTaken ?? '';

      // Visual Checkpoints
      _isLuminaireClean = existingReport?.isLuminaireClean ?? true;
      _isGlareShielded = existingReport?.isGlareShielded ?? true;
      _isFlickerFree = existingReport?.isFlickerFree ?? true;

      // Grid controllers
      for (int i = 0; i < 9; i++) {
        _gridControllers[i].text = existingReport != null ? '${existingReport.gridReadings[i]}' : '';
      }

      _calculateMetrics();
    });
  }

  void _calculateMetrics() {
    final List<int> values = [];
    for (var ctrl in _gridControllers) {
      final val = int.tryParse(ctrl.text.trim());
      if (val != null) {
        values.add(val);
      }
    }

    final details = getDetailsForType(_selectedLocation!['type'] ?? '');
    final int lowLux = details['lowLux'] as int? ?? 100;
    final int midLux = details['midLux'] as int? ?? 150;
    final int highLux = details['highLux'] as int? ?? 200;
    final double targetUniformity = details['uniformity'] as double? ?? 0.40;

    if (values.isEmpty) {
      setState(() {
        _averageLux = 0.0;
        _uniformityRatio = 0.0;
        _status = 'Fail';
        _rangeTag = 'Below Standard';
      });
      return;
    }

    final sum = values.reduce((a, b) => a + b);
    final avg = sum / 9.0;
    int minVal = values.reduce((a, b) => a < b ? a : b);
    final double ratio = avg == 0.0 ? 0.0 : minVal / avg;

    setState(() {
      _averageLux = avg;
      _uniformityRatio = ratio;

      // IS 3646 Standard Verification Logic:
      if (_averageLux >= lowLux && _uniformityRatio >= targetUniformity && _isLuminaireClean && _isFlickerFree) {
        _status = 'Pass';
        if (_averageLux >= highLux) {
          _rangeTag = 'High Range (Superior)';
        } else if (_averageLux >= midLux) {
          _rangeTag = 'Mid Range (Optimal)';
        } else {
          _rangeTag = 'Low Range (Acceptable)';
        }
      } else {
        _status = 'Fail';
        if (_averageLux < lowLux) {
          _rangeTag = 'Low Lux (Below Min)';
        } else if (_uniformityRatio < targetUniformity) {
          _rangeTag = 'Non-Uniform Distribution';
        } else {
          _rangeTag = 'Visual Check Failed';
        }
      }
    });
  }

  // --- Submit Lux Level Test Report ---
  Future<void> _submitInspectionReport() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) return;

    // Action plan validation ONLY required during Retest mode
    if (_checkType == 'Retest' && _actionTakenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrective Action Plan is required when submitting a Retest.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final details = getDetailsForType(_selectedLocation!['type'] ?? '');
    final String category = _selectedLocation!['category'] ?? getCategoryForType(_selectedLocation!['type'] ?? '');
    final String compassOrientation = _selectedLocation!['compassOrientation'] ?? 'North-Up';
    final List<int> readings = [];

    for (var c in _gridControllers) {
      final val = int.tryParse(c.text.trim());
      if (val == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid numeric readings in all 9 grid boxes.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      readings.add(val);
    }

    setState(() => _isSubmitting = true);

    try {
      final reportId = _editingReportId ?? const Uuid().v4();
      final bool isEdit = _editingReportId != null;

      final report = LuxLevelReportModel(
        id: reportId,
        plantId: _selectedPlantId!,
        unitId: _selectedUnitId!,
        locationId: _selectedLocation!['id'],
        locationName: _selectedLocation!['name'],
        locationType: _selectedLocation!['type'],
        category: category,
        tableRef: details['tableRef'] ?? 'IS 3646',
        lowLux: details['lowLux'] as int? ?? 100,
        midLux: details['midLux'] as int? ?? 150,
        highLux: details['highLux'] as int? ?? 200,
        targetUniformity: details['uniformity'] as double? ?? 0.40,
        benchmarkRa: details['ra'] as int? ?? 70,
        benchmarkRUG: details['rugl'] as int? ?? 25,
        planeHeight: details['plane'] ?? 'Floor level (0.0 m)',
        referenceLux: details['midLux'] as int? ?? 150,
        measuredLux: _averageLux.round(),
        status: _status,
        rangeTag: _rangeTag,
        testedBy: isEdit ? (_selectedLocation!['latestReport'] as LuxLevelReportModel?)?.testedBy ?? _currentUserName : _currentUserName,
        testingDate: _testDate,
        remarks: _remarksController.text.trim(),
        isLuminaireClean: _isLuminaireClean,
        isGlareShielded: _isGlareShielded,
        isFlickerFree: _isFlickerFree,
        gridReadings: readings,
        averageLux: _averageLux,
        uniformityRatio: _uniformityRatio,
        compassOrientation: compassOrientation,
        checkType: _checkType,
        actionTaken: _actionTakenController.text.trim(),
      );

      final Map<String, dynamic> docData = report.toMap();
      if (isEdit) {
        docData['lastModifiedBy'] = _currentUserName;
        docData['lastModifiedAt'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection('lux_level_reports').doc(reportId).set(docData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Inspection Report Updated Successfully!' : 'Lux Inspection Submitted Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedLocation = null;
          _editingReportId = null;
        });
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- Export Excel Audit Report (Includes All 3 Visual Checks Explicitly) ---
  Future<void> _exportExcelReport() async {
    try {
      final List<Map<String, dynamic>> excelData = _processedLocations.map((loc) {
        final rawId = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
        final LuxLevelReportModel? r = loc['latestReport'];
        final details = getDetailsForType(loc['type'] ?? '');
        final category = loc['category'] ?? getCategoryForType(loc['type'] ?? '');

        return {
          'Location ID': rawId,
          'Area Name': loc['name'] ?? '',
          'Category': category,
          'Sub-Type': loc['type'] ?? '',
          'IS 3646 Ref': details['tableRef'] ?? 'IS 3646',
          'Standard Scale Range': '${details['lowLux']} - ${details['midLux']} - ${details['highLux']} lx',
          'Min Req Lux (Low)': details['lowLux'] ?? 100,
          'Standard Target Lux (Mid)': details['midLux'] ?? 150,
          'High Lux (Superior)': details['highLux'] ?? 200,
          'Avg Measured Lux': r?.averageLux.toStringAsFixed(1) ?? 'N/A',
          'Min Lux': r != null ? (r.gridReadings.reduce((a, b) => a < b ? a : b)) : 'N/A',
          'Max Lux': r != null ? (r.gridReadings.reduce((a, b) => a > b ? a : b)) : 'N/A',
          'P1 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[0] : 'N/A',
          'P2 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[1] : 'N/A',
          'P3 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[2] : 'N/A',
          'P4 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[3] : 'N/A',
          'P5 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[4] : 'N/A',
          'P6 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[5] : 'N/A',
          'P7 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[6] : 'N/A',
          'P8 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[7] : 'N/A',
          'P9 (lx)': r != null && r.gridReadings.length >= 9 ? r.gridReadings[8] : 'N/A',
          'Required Min Uniformity': '>= ${details['uniformity'] ?? 0.40}',
          'Measured Uniformity': r != null ? '${r.uniformityRatio.toStringAsFixed(2)} (Req: >= ${details['uniformity']})' : 'N/A',
          'CRI (Ra)': details['ra'] ?? 70,
          'Glare (RUGL)': details['rugl'] ?? 25,
          'Performance Range Tag': r?.rangeTag ?? 'N/A',
          'Optics Cleanliness (fm)': r != null ? (r.isLuminaireClean ? 'PASS' : 'FAIL') : 'N/A',
          'Direct Glare Shielded (alpha)': r != null ? (r.isGlareShielded ? 'PASS' : 'FAIL') : 'N/A',
          'Stroboscopic Safety (SVM <= 1.0)': r != null ? (r.isFlickerFree ? 'PASS' : 'FAIL') : 'N/A',
          'Status': loc['status'] ?? 'Never Tested',
          'Corrective Action Plan': r?.actionTaken ?? 'N/A',
          'Tested By': r?.testedBy ?? 'N/A',
          'Testing Date': r != null ? _formatDate(r.testingDate) : 'N/A',
          'Remarks': r?.remarks ?? '',
        };
      }).toList();

      final fileName = 'Lux_Audit_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = ExcelService().generateExcel(excelData, 'Lux Audit');

      if (bytes != null) {
        final path = await downloadFile(bytes, fileName);
        if (path != null) {
          _handleSavedFile(path, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Excel report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Export PDF Compliance Document (Includes All 3 Visual Checks Explicitly) ---
  Future<void> _exportPDFReport() async {
    final pdf = pw.Document();
    final String reportGenTime = _formatDateTime(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return [
            // Clean Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VEDANTA IRON & STEEL LIMITED', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Illumination Compliance & Lux Audit Report', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Ref Standard: IS 3646 (Part 1) : 2025', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text('Plant: $_selectedPlantId | Unit: $_selectedUnitId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900)),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('Report Generated: $reportGenTime', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Summary Stats Box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  pw.Expanded(child: _pdfStatItem('Total Areas', '$_totalLocations')),
                  pw.Expanded(child: _pdfStatItem('Compliant (PASS)', '$_compliantCount', color: PdfColors.green800)),
                  pw.Expanded(child: _pdfStatItem('Low Lux / Non-Uniform', '$_lowLuxCount', color: PdfColors.red800)),
                  pw.Expanded(child: _pdfStatItem('Overdue / Unchecked', '$_overdueCount', color: PdfColors.orange800)),
                  pw.Expanded(child: _pdfStatItem('Compliance Score', '${_complianceRate.toStringAsFixed(1)}%', color: PdfColors.blue900)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Optimized Landscape Data Table (With 3 Visual Checkpoints Column)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7), // ID
                1: const pw.FlexColumnWidth(1.5), // Area Name & Category
                2: const pw.FlexColumnWidth(1.3), // Sub-Type & Ref Table
                3: const pw.FlexColumnWidth(0.9), // Scale Range
                4: const pw.FlexColumnWidth(0.7), // Avg Lux
                5: const pw.FlexColumnWidth(1.9), // P1..P9 Grid Readings
                6: const pw.FlexColumnWidth(0.6), // Uo Ratio
                7: const pw.FlexColumnWidth(1.0), // Rating Tag
                8: const pw.FlexColumnWidth(1.1), // 3 Visual Checkpoints
                9: const pw.FlexColumnWidth(1.2), // Status & Action Plan
                10: const pw.FlexColumnWidth(0.8), // Tested By
                11: const pw.FlexColumnWidth(0.7), // Test Date (End Column)
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _pdfHeaderCell('ID'),
                    _pdfHeaderCell('Area Name'),
                    _pdfHeaderCell('Sub-Type'),
                    _pdfHeaderCell('Scale Range'),
                    _pdfHeaderCell('Avg Lux'),
                    _pdfHeaderCell('9-Point Grid (P1-P9 lx)'),
                    _pdfHeaderCell('Uo (Min Req)'),
                    _pdfHeaderCell('Rating Tag'),
                    _pdfHeaderCell('Visual Checks (3)'),
                    _pdfHeaderCell('Status & Action Plan'),
                    _pdfHeaderCell('Tested By'),
                    _pdfHeaderCell('Test Date'),
                  ],
                ),
                ..._processedLocations.map((itemLoc) {
                  final rawId = HierarchyService.stripPrefix(itemLoc['id'], _selectedPlantId!, _selectedUnitId!);
                  final LuxLevelReportModel? r = itemLoc['latestReport'];
                  final details = getDetailsForType(itemLoc['type'] ?? '');
                  final String statusStr = itemLoc['status'] ?? 'Never Tested';
                  final bool isPass = statusStr == 'Compliant';

                  final String gridString = r != null && r.gridReadings.length >= 9
                      ? "P1:${r.gridReadings[0]} P2:${r.gridReadings[1]} P3:${r.gridReadings[2]}\nP4:${r.gridReadings[3]} P5:${r.gridReadings[4]} P6:${r.gridReadings[5]}\nP7:${r.gridReadings[6]} P8:${r.gridReadings[7]} P9:${r.gridReadings[8]}"
                      : "No Readings";

                  final String visualChecksStr = r != null
                      ? "Optics: ${r.isLuminaireClean ? 'OK' : 'DIRT'}\nGlare: ${r.isGlareShielded ? 'OK' : 'BAD'}\nFlicker: ${r.isFlickerFree ? 'OK' : 'FLK'}"
                      : "-";

                  final String actionString = (r != null && r.actionTaken.isNotEmpty) ? "\nAction: ${r.actionTaken}" : "";
                  final String uoDisplay = r != null ? "${r.uniformityRatio.toStringAsFixed(2)}\n(>= ${details['uniformity']})" : "-";

                  return pw.TableRow(
                    children: [
                      _pdfDataCell(rawId, isBold: true),
                      _pdfDataCell('${itemLoc['name']}\n(${itemLoc['category'] ?? getCategoryForType(itemLoc['type'] ?? '')})'),
                      _pdfDataCell('${itemLoc['type']}\n[${details['tableRef']}]'),
                      _pdfDataCell('${details['lowLux']}-${details['midLux']}-${details['highLux']} lx'),
                      _pdfDataCell(r != null ? r.averageLux.toStringAsFixed(1) : '-', isBold: true),
                      _pdfDataCell(gridString, isBold: true),
                      _pdfDataCell(uoDisplay, isBold: true),
                      _pdfDataCell(r?.rangeTag ?? '-'),
                      _pdfDataCell(visualChecksStr),
                      _pdfDataCell('$statusStr$actionString', color: isPass ? PdfColors.green800 : PdfColors.red800, isBold: true),
                      _pdfDataCell(r?.testedBy ?? '-'),
                      _pdfDataCell(r != null ? _formatDate(r.testingDate) : '-'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // Standard Footer & Sign-off
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('IS 3646:2025 Standard Norms Applied:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.Text('- Minimum Passing Target: Low Lux level (Clause 5.2.2.1)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    pw.Text('- Target Uniformity: Uo >= 0.40 (Plant Floors) / Uo >= 0.60 (Control Rooms / SCADA)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    pw.Text('- 3 Visual Checkpoints: Optics Cleanliness (fm), Glare Shielding Angle (alpha >= 15-30 deg), Stroboscopic Machine Safety (SVM <= 1.0)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Tested By: $_currentUserName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Approved By: Plant Electrical Head / HOD', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final fileName = 'Lux_Compliance_Report_${_selectedPlantId}_${_selectedUnitId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();
    final path = await downloadFile(bytes, fileName);

    if (path != null) {
      _handleSavedFile(path, fileName);
    }
  }

  pw.Widget _pdfStatItem(String label, String value, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 1),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
    );
  }

  pw.Widget _pdfDataCell(String text, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    );
  }

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
                  'IS 3646 (Part 1) : 2025 Illumination Audit Guide',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bureau of Indian Standards Code of Practice for Interior Illumination (Second Revision, July 2025). Applicable for Heavy Industrial, Pig Iron & Steel Manufacturing Facilities.',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const Divider(height: 24),

          // Section 1: Standard Area Schedule
          const Text(
            '1. Standard Area Requirements (IS 3646:2025 Category 1 to 8)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
          ),
          const SizedBox(height: 4),
          const Text(
            'Maintained Lux (Eₘ), Scale Range (Low - Mid - High), Uniformity Ratio (U₀), Color Rendering Index (Rₐ), Glare Limit (Rᵤɢₗ), and Measurement Plane height per area category:',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          ...luxCategories.entries.map((catEntry) {
            final catName = catEntry.key;
            final items = catEntry.value;

            return ExpansionTile(
              initiallyExpanded: false,
              title: Text(catName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              children: items.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              d['type'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${d['midLux']} Lux',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(d['desc'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _helpBadge('Table Ref', d['tableRef'] as String, Colors.cyanAccent),
                          _helpBadge('Scale Range', '${d['lowLux']} - ${d['midLux']} - ${d['highLux']} lx', Colors.amberAccent),
                          _helpBadge('Min Uniformity (U₀)', '≥ ${d['uniformity']}', Colors.greenAccent),
                          _helpBadge('Min CRI (Rₐ)', '≥ ${d['ra']}', Colors.orangeAccent),
                          _helpBadge('Glare Limit (Rᵤɢₗ)', '≤ ${d['rugl']}', Colors.purpleAccent),
                          _helpBadge('Plane', '${d['plane']}', Colors.white70),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),

          const Divider(height: 28),

          // Section 2: Field Audit Procedure
          const Text(
            '2. Practical Field Audit Method (Lux Meter & Measuring Tape)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Measurement Plane Height: Record readings at 0.8 m for desks/control panels, 0.0 m (floor level) for walkways, sheds, & cast house, and 1.2–1.6 m for standing workstations.\n\n'
            '• Wall Exclusion Zone: Exclude a perimeter band equal to 15% of the shortest room dimension or 0.5 m (whichever is smaller) to avoid wall reflection shadows.\n\n'
            '• Grid Sizing (Clause 5.2.2.6): Maximum grid cell size is calculated as p = 0.2 × 5^(log₁₀ d), capped at p ≤ 10 m.\n\n'
            '• Large Rooms & Industrial Halls: Large sheds or long plant bays (> 20 m) are audited by establishing Zone / Bay-wise 9-point audit locations (e.g. Raw Material Shed Bay A, Bay B).',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),

          const Divider(height: 28),

          // Section 3: Mathematical Formulas
          const Text(
            '3. Core Evaluation Formulas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average Illuminance (Eₐᵥ₉):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                SizedBox(height: 2),
                Text('Eₐᵥ₉ = (P₁ + P₂ + P₃ + P₄ + P₅ + P₆ + P₇ + P₈ + P₉) / 9', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                SizedBox(height: 10),

                Text('Illuminance Uniformity Ratio (U₀):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                SizedBox(height: 2),
                Text('U₀ = Minimum Measured Lux (Eₘᵢₙ) / Average Lux (Eₐᵥ₉)\n• Pass Threshold: U₀ ≥ 0.40 (General Plant) / U₀ ≥ 0.60 (Control Rooms)', style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3)),
                SizedBox(height: 10),

                Text('Initial Illuminance Target (Eᵢ):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                SizedBox(height: 2),
                Text('Eᵢ = Maintained Lux Target (Eₘ) / Maintenance Factor (fₘ)\n• fₘ ≈ 0.80 (Clean Office), 0.70 (Substation), 0.65 (Dusty Heavy Plant)', style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3)),
              ],
            ),
          ),

          const Divider(height: 28),

          // Section 4: Performance Bands
          const Text(
            '4. Lighting Performance Rating Bands (IS 3646 Clause 5.2.2.1)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
          ),
          const SizedBox(height: 8),
          const Text(
            '• High Range (Superior - PASS): Average Lux ≥ High scale value. Exceeds standard requirements.\n\n'
            '• Mid Range (Optimal - PASS): Average Lux ≥ Mid scale value. Optimal recommended illumination.\n\n'
            '• Low Range (Acceptable - PASS): Average Lux ≥ Low scale value. Meets minimum standard compliance.\n\n'
            '• Low Lux / Non-Uniform (FAIL): Average Lux < Low scale value OR Uniformity Ratio U₀ < Target.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),

          const Divider(height: 28),

          // Section 5: Visual Checkpoints
          const Text(
            '5. Visual Observational Checkpoints (No Special Meters Required)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Fitting & Optics Cleanliness: Inspect fixture glass covers and diffusers for heavy dust, soot, or yellowing affecting the Maintenance Factor (fₘ).\n\n'
            '2. Direct Glare Shielding: Check if bare light sources are in direct line of sight. Ensure shielding angle α ≥ 15°–30° (Table 4).\n\n'
            '3. Stroboscopic Safety: Verify absence of visible flicker (SVM ≤ 1.0) near rotating machinery (conveyors, blowers, crushers).\n\n'
            '4. ISO 3864-1 Safety Colors: Confirm Red (Fire/Stop), Yellow (Hazard), Green (Exit/Safety), and Blue (Mandatory) safety signs are clearly distinguishable.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _helpBadge(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

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
                    await Share.shareXFiles([XFile(path)], text: 'Lux Level Report: $fileName');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Lux Level Checklist'),
        body: Center(child: PulseLoading()),
      );
    }

    return PopScope(
      canPop: _selectedLocation == null && _historyLocation == null && !_isManagingLocations && !_showHelp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (_selectedLocation != null) {
            _selectedLocation = null;
            _editingReportId = null;
          } else if (_historyLocation != null) {
            _historyLocation = null;
          } else if (_isManagingLocations) {
            _isManagingLocations = false;
          } else if (_showHelp) {
            _showHelp = false;
          }
        });
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Lux Level Checklist'),
        body: _selectedLocation != null
            ? _buildRecordingFormView()
            : _historyLocation != null
                ? _buildHistoryView()
                : _isManagingLocations
                    ? _buildManageLocationsView()
                    : _showHelp
                        ? _buildHelpView()
                        : _buildLocationListView(),
      ),
    );
  }

  Widget _buildLocationListView() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLocations = _processedLocations.where((loc) {
      final name = (loc['name'] ?? '').toString().toLowerCase();
      final type = (loc['type'] ?? '').toString().toLowerCase();
      final id = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!).toLowerCase();
      return name.contains(query) || type.contains(query) || id.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Compact Scope Selectors (Short Code Display matching RCCB Style)
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
                          : (val) async {
                              if (val != null) {
                                setState(() {
                                  _selectedPlantId = val;
                                  _updateUnitList();
                                  _isLoading = true;
                                });
                                await _loadData();
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
                      items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _isUnitLocked
                          ? null
                          : (val) async {
                              if (val != null) {
                                setState(() {
                                  _selectedUnitId = val;
                                  _isLoading = true;
                                });
                                await _loadData();
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

          // 2. Metrics Dashboard Card
          GlassContainer(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lux Compliance Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _complianceRate >= 80.0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_complianceRate.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _complianceRate >= 80.0 ? Colors.greenAccent : Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total Areas', '$_totalLocations', Colors.white),
                      _buildStatItem('Compliant', '$_compliantCount', Colors.greenAccent),
                      _buildStatItem('Low / Uneven', '$_lowLuxCount', Colors.redAccent),
                      _buildStatItem('Overdue', '$_overdueCount', Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Search Field & Manage Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search area name or ID...',
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
                tooltip: 'IS 3646 Help Guide',
                onPressed: () => setState(() => _showHelp = true),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Manage Locations',
                  onPressed: () => setState(() => _isManagingLocations = true),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 4. Header Row with Title & Text Excel / PDF Action Buttons (RCCB Style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lux Locations (${filteredLocations.length})',
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
                    onPressed: _exportPDFReport,
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    label: const Text('PDF Report', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Locations List Cards
          filteredLocations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No matching Lux locations found.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLocations.length,
                  itemBuilder: (context, idx) {
                    final loc = filteredLocations[idx];
                    final rawId = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
                    final String status = loc['status'];
                    final LuxLevelReportModel? latest = loc['latestReport'];
                    final details = getDetailsForType(loc['type'] ?? '');
                    final int lowLuxStd = details['lowLux'] as int? ?? 100;
                    final int midLuxStd = details['midLux'] as int? ?? 150;
                    final int highLuxStd = details['highLux'] as int? ?? 200;

                    Color statusColor = Colors.grey;
                    if (status == 'Compliant') statusColor = Colors.greenAccent;
                    if (status == 'Low Lux') statusColor = Colors.redAccent;
                    if (status == 'Overdue') statusColor = Colors.orangeAccent;

                    final String rangeTagStr = latest != null ? latest.rangeTag : 'Scale: $lowLuxStd - $midLuxStd - $highLuxStd lx';

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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.light_mode, color: statusColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$rawId - ${loc['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text('${details['tableRef']} • Scale: $lowLuxStd - $midLuxStd - $highLuxStd Lux (Plane: ${details['plane']})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                ),
                              ],
                            ),
                            const Divider(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      latest != null
                                          ? 'Last Test: ${latest.measuredLux} Lux | U₀: ${latest.uniformityRatio.toStringAsFixed(2)} (${_formatDate(latest.testingDate)})'
                                          : 'Last Test: Never Tested',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      latest != null ? 'Rating: $rangeTagStr' : 'Date: N/A',
                                      style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                    ),
                                    if (latest != null && latest.actionTaken.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text('Action Plan: ${latest.actionTaken}', style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontStyle: FontStyle.italic)),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history, color: Colors.blueAccent, size: 20),
                                      tooltip: 'Inspection History',
                                      onPressed: () => setState(() => _historyLocation = loc),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.speed, size: 14, color: Colors.white),
                                      label: Text(status == 'Low Lux' || status == 'Overdue' ? 'Retest' : 'Record', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () => _startRecordOrEdit(loc, null),
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

  Widget _buildRecordingFormView() {
    final rawId = HierarchyService.stripPrefix(_selectedLocation!['id'], _selectedPlantId!, _selectedUnitId!);
    final details = getDetailsForType(_selectedLocation!['type'] ?? '');
    final String category = _selectedLocation!['category'] ?? getCategoryForType(_selectedLocation!['type'] ?? '');
    final String compassOrientation = _selectedLocation!['compassOrientation'] ?? 'North-Up';
    final bool isEdit = _editingReportId != null;

    String topLabel = 'N';
    String bottomLabel = 'S';
    String leftLabel = 'W';
    String rightLabel = 'E';

    if (compassOrientation == 'East-Up') {
      topLabel = 'E'; bottomLabel = 'W'; leftLabel = 'N'; rightLabel = 'S';
    } else if (compassOrientation == 'South-Up') {
      topLabel = 'S'; bottomLabel = 'N'; leftLabel = 'E'; rightLabel = 'W';
    } else if (compassOrientation == 'West-Up') {
      topLabel = 'W'; bottomLabel = 'E'; leftLabel = 'S'; rightLabel = 'N';
    }

    final double targetUniformity = details['uniformity'] as double? ?? 0.40;
    final int lowLuxStd = details['lowLux'] as int? ?? 100;
    final int midLuxStd = details['midLux'] as int? ?? 150;
    final int highLuxStd = details['highLux'] as int? ?? 200;
    final String planeHeight = details['plane'] as String? ?? 'Floor level (0.0 m)';

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
                  _selectedLocation = null;
                  _editingReportId = null;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit ? 'Edit Report: $rawId' : 'Record 9-Point Lux: $rawId',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comprehensive Area Guidance Card (Includes Category, Test Plane & Scale Bands Details)
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Area: ${_selectedLocation!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text('Plane: $planeHeight', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  Text('${details['tableRef']} • Sub-Type: ${_selectedLocation!['type']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),

                  // Rating Bands Summary Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _badgeChip('Low Band (Min Target)', '$lowLuxStd Lux', Colors.orangeAccent),
                      _badgeChip('Mid Band (Optimal)', '$midLuxStd Lux', Colors.greenAccent),
                      _badgeChip('High Band (Superior)', '$highLuxStd Lux', Colors.cyanAccent),
                      _badgeChip('Min Uniformity (Uo)', '>= $targetUniformity', Colors.purpleAccent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Orientation Reference: $compassOrientation', style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Form Body
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inspection type switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Inspection Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                const SizedBox(height: 16),

                // Visual Inspection Checkpoints (No Meter Needed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Visual Observational Checkpoints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Luminaire Optics Clean (No soot/heavy dirt accumulation)', style: TextStyle(fontSize: 11)),
                        value: _isLuminaireClean,
                        onChanged: (v) {
                          setState(() => _isLuminaireClean = v ?? true);
                          _calculateMetrics();
                        },
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Direct Glare Shielded (Diffusers/Louvers intact)', style: TextStyle(fontSize: 11)),
                        value: _isGlareShielded,
                        onChanged: (v) {
                          setState(() => _isGlareShielded = v ?? true);
                          _calculateMetrics();
                        },
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('No Visible Machine Flicker / Stroboscopic Effect', style: TextStyle(fontSize: 11)),
                        value: _isFlickerFree,
                        onChanged: (v) {
                          setState(() => _isFlickerFree = v ?? true);
                          _calculateMetrics();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Closed-Loop Corrective Action Plan Section (ONLY SHOWN IN RETEST MODE)
                if (_checkType == 'Retest') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_circle_outlined, size: 18, color: Colors.orangeAccent),
                            SizedBox(width: 6),
                            Text(
                              'Corrective Action Plan * (Required for Retest)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orangeAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Quick Action Presets (Tap to insert):', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _actionPlanPresets.map((preset) {
                            return ActionChip(
                              label: Text(preset, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                final currentText = _actionTakenController.text.trim();
                                if (currentText.isEmpty) {
                                  _actionTakenController.text = preset;
                                } else if (!currentText.contains(preset)) {
                                  _actionTakenController.text = '$currentText; $preset';
                                }
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _actionTakenController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Action Details Taken / Planned *',
                            hintText: 'e.g. Installed 4 new 150W LED bay lights, cleaned optics',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_checkType == 'Retest' && (v == null || v.trim().isEmpty)) {
                              return 'Please state the corrective action taken to resolve low lux';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3x3 Grid Layout representation
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade900.withValues(alpha: 0.5),
                    ),
                    child: Stack(
                      children: [
                        Align(alignment: Alignment.topCenter, child: Text(topLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 12))),
                        Align(alignment: Alignment.bottomCenter, child: Text(bottomLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                        Align(alignment: Alignment.centerLeft, child: Text(leftLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                        Align(alignment: Alignment.centerRight, child: Text(rightLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              return TextFormField(
                                controller: _gridControllers[idx],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.black.withValues(alpha: 0.3),
                                  hintText: 'P${idx + 1}',
                                  hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                                onChanged: (_) => _calculateMetrics(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Calculation summary card
                GlassContainer(
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Average Lux', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('${_averageLux.toStringAsFixed(1)} lx', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Uniformity (U₀)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  _uniformityRatio.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _uniformityRatio >= targetUniformity ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Result Status', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  _status,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _status == 'Pass' ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('IS 3646 Rating Tag: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              _rangeTag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _status == 'Pass' ? Colors.cyanAccent : Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Observations (Optional)',
                    hintText: 'e.g. Area clean, fittings working normally',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white),
                  label: Text(_isSubmitting ? 'Saving Report...' : (isEdit ? 'Update Report' : 'Submit Lux Inspection'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: _isSubmitting ? null : _submitInspectionReport,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(val, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    final List<LuxLevelReportModel> history = List<LuxLevelReportModel>.from(_historyLocation!['history'] ?? []);
    final rawId = HierarchyService.stripPrefix(_historyLocation!['id'], _selectedPlantId!, _selectedUnitId!);
    final details = getDetailsForType(_historyLocation!['type'] ?? '');
    final String category = _historyLocation!['category'] ?? getCategoryForType(_historyLocation!['type'] ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _historyLocation = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Inspection History: $rawId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Area Info Card
          GlassContainer(
            borderRadius: 16,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Area Name: ${_historyLocation!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Category: $category', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  Text('${details['tableRef']} • Scale Range: ${details['lowLux']} - ${details['midLux']} - ${details['highLux']} lx (Plane: ${details['plane']})', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  Text('Target Uniformity: ≥ ${details['uniformity']} | CRI: ≥ ${details['ra']} | Glare Limit: ≤ ${details['rugl']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Text('No historical logs found for this area.'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, idx) {
                    final rep = history[idx];
                    final bool showActions = _canEditOrDeleteReport(rep.testingDate, rep.testedBy);
                    final String compassOrientation = rep.compassOrientation;

                    String topLabel = 'N';
                    String bottomLabel = 'S';
                    String leftLabel = 'W';
                    String rightLabel = 'E';

                    if (compassOrientation == 'East-Up') {
                      topLabel = 'E'; bottomLabel = 'W'; leftLabel = 'N'; rightLabel = 'S';
                    } else if (compassOrientation == 'South-Up') {
                      topLabel = 'S'; bottomLabel = 'N'; leftLabel = 'E'; rightLabel = 'W';
                    } else if (compassOrientation == 'West-Up') {
                      topLabel = 'W'; bottomLabel = 'E'; leftLabel = 'S'; rightLabel = 'N';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: rep.checkType == 'Retest' ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(rep.checkType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rep.checkType == 'Retest' ? Colors.orangeAccent : Colors.blueAccent)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_formatDate(rep.testingDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: rep.status == 'Pass' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${rep.measuredLux} Lux (${rep.status})',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: rep.status == 'Pass' ? Colors.greenAccent : Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Measured Avg: ${rep.averageLux.toStringAsFixed(1)} Lux | Uniformity U₀: ${rep.uniformityRatio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Rating Tag: ${rep.rangeTag}', style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                            Text(
                              'Visual Checks: Optics Clean: ${rep.isLuminaireClean ? 'PASS' : 'FAIL'} | Shielded: ${rep.isGlareShielded ? 'PASS' : 'FAIL'} | Flicker Free: ${rep.isFlickerFree ? 'PASS' : 'FAIL'}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),

                            if (rep.actionTaken.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                                ),
                                child: Text('Corrective Action Taken: ${rep.actionTaken}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Mini 3x3 Grid view with P1 to P9 readings
                            Center(
                              child: Container(
                                width: 160,
                                height: 160,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade800),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                child: Stack(
                                  children: [
                                    Align(alignment: Alignment.topCenter, child: Text(topLabel, style: const TextStyle(fontSize: 8, color: Colors.amberAccent, fontWeight: FontWeight.bold))),
                                    Align(alignment: Alignment.bottomCenter, child: Text(bottomLabel, style: const TextStyle(fontSize: 8, color: Colors.grey))),
                                    Align(alignment: Alignment.centerLeft, child: Text(leftLabel, style: const TextStyle(fontSize: 8, color: Colors.grey))),
                                    Align(alignment: Alignment.centerRight, child: Text(rightLabel, style: const TextStyle(fontSize: 8, color: Colors.grey))),

                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 4,
                                          mainAxisSpacing: 4,
                                          childAspectRatio: 1.3,
                                        ),
                                        itemCount: 9,
                                        itemBuilder: (context, gIdx) {
                                          final val = gIdx < rep.gridReadings.length ? rep.gridReadings[gIdx] : 0;
                                          return Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade800),
                                              borderRadius: BorderRadius.circular(4),
                                              color: Colors.black.withValues(alpha: 0.4),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('P${gIdx + 1}', style: const TextStyle(fontSize: 6, color: Colors.grey)),
                                                Text('$val lx', style: const TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tested By: ${rep.testedBy}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      if (rep.remarks.isNotEmpty)
                                        Text('Remarks: ${rep.remarks}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
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
                                          final targetLoc = _historyLocation!;
                                          setState(() => _historyLocation = null);
                                          _startRecordOrEdit(targetLoc, rep);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        onPressed: () => _confirmDeleteReport(rep.id, _historyLocation!),
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

  Widget _buildManageLocationsView() {
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
                  _isManagingLocations = false;
                }),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Manage Lux Locations',
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
                  label: const Text('Add New Lux Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditLocationDialog(null, () async {
                    await _loadData();
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
                          collectionId: 'lux_locations',
                          title: 'Lux Locations',
                          plantId: _selectedPlantId,
                          unitId: _selectedUnitId,
                        ),
                      ),
                    );
                    await _loadData();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _locations.isEmpty
              ? const Center(child: Text('No locations found. Add one above!'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _locations.length,
                  itemBuilder: (context, idx) {
                    final loc = _locations[idx];
                    final rawId = HierarchyService.stripPrefix(loc['id'], _selectedPlantId!, _selectedUnitId!);
                    final details = getDetailsForType(loc['type'] ?? '');
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('$rawId - ${loc['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Category: ${loc['category'] ?? getCategoryForType(loc['type'] ?? '')}\nType: ${loc['type']} (${details['tableRef']})\nScale: ${details['lowLux']} - ${details['midLux']} - ${details['highLux']} Lux',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.amberAccent, size: 20),
                              onPressed: () => _showAddEditLocationDialog(loc, () async {
                                await _loadData();
                                setState(() {});
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteLocation(loc, () async {
                                await _loadData();
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
