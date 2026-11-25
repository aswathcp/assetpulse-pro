import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_roles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/excel_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/location_model.dart';
import '../../../assets/data/models/panel_model.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../../core/utils/file_download_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class HierarchyImportPage extends StatefulWidget {
  final String collectionId;
  final String title;
  final String? unitId;
  final String? plantId;

  const HierarchyImportPage({
    super.key,
    required this.collectionId,
    required this.title,
    this.unitId,
    this.plantId,
  });

  @override
  State<HierarchyImportPage> createState() => _HierarchyImportPageState();
}

class _HierarchyImportPageState extends State<HierarchyImportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelService _excelService = ExcelService();

  String? _fileName;
  List<Map<String, dynamic>> _previewData = [];
  String _selectedPreviewTab = 'all';
  bool _isProcessing = false;
  String? _statusMessage;
  String? _userUnitId;
  String? _userPlantId;

  // Scope State
  List<String> _plants = [];
  List<String> _units = [];
  bool _isPlantLocked = false;
  bool _isUnitLocked = false;
  String _userRole = '';
  bool _isAdmin = false;

  // Cascading context
  List<LocationModel> _locations = [];
  List<PanelModel> _panels = [];
  String? _selectedLocationId;
  String? _selectedPanelId;

  @override
  void initState() {
    super.initState();
    _loadScope();
  }

  Future<void> _loadScope() async {
    final user = AuthService().currentUser;
    if (user == null) {
      return;
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (profile == null) {
      return;
    }

    _userRole = profile['role'] ?? AppRoles.guest;
    final userPlantId = profile['plantId'] as String?;
    final userUnitId = profile['unitId'] as String?;
    final userBusinessId = profile['businessId'] as String? ?? 'VISL';

    await HierarchyService().init(businessId: userBusinessId);
    _plants = HierarchyService().getPlants();
    _isAdmin = profile['isAdmin'] == true;

    final String? cleanPlant = (userPlantId == null || userPlantId.isEmpty || userPlantId == 'Unknown') ? null : userPlantId;
    final String? cleanUnit = (userUnitId == null || userUnitId.isEmpty || userUnitId == 'Unknown') ? null : userUnitId;

    final bool hasGlobalAdmin = _isAdmin && cleanPlant == null;
    final bool hasPlantAdmin = _isAdmin && cleanPlant != null;

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
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
    } else if (isPlantScope) {
      _isPlantLocked = true;
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = false;
    } else {
      _isPlantLocked = true;
      _userPlantId = widget.plantId ?? cleanPlant ?? (_plants.isNotEmpty ? _plants.first : null);
      _isUnitLocked = true;
      _userUnitId = widget.unitId ?? cleanUnit;
    }

    _updateUnitList();

    if (!_isUnitLocked) {
      _userUnitId = widget.unitId ?? cleanUnit ?? (_units.isNotEmpty ? _units.first : null);
    }

    if (mounted) {
      setState(() {});
      _loadHierarchyData();
    }
  }

  void _updateUnitList() {
    if (_userPlantId == null) {
      _units = [];
      _userUnitId = null;
    } else {
      _units = HierarchyService().getUnitsForPlant(_userPlantId!);
      if (!_units.contains(_userUnitId)) {
        _userUnitId = _units.isNotEmpty ? _units.first : null;
      }
    }
  }

  Future<void> _loadHierarchyData() async {
    if (_userUnitId == null || _userPlantId == null) return;

    if (['panels', 'feeders', 'master_equipments'].contains(widget.collectionId)) {
      if (widget.collectionId == 'panels') {
        _firestoreService.getPanelRoomsStream(_userUnitId!, _userPlantId!).listen((rooms) {
          if (mounted) {
            setState(() {
              _locations = rooms.map((r) => LocationModel(
                id: r.id,
                unitId: r.unitId,
                plantId: r.plantId,
                name: r.name,
                type: 'Panel Room',
                description: r.description,
              )).toList();
            });
          }
        });
      } else {
        _firestoreService.getLocationsStream(_userUnitId!, _userPlantId!).listen((locs) {
          if (mounted) {
            setState(() {
              _locations = locs;
            });
          }
        });
      }
    }
  }

  void _onLocationChanged(String? locId) {
    setState(() {
      _selectedLocationId = locId;
      _selectedPanelId = null;
      _panels = [];
    });
    if (locId != null) {
      _firestoreService.getPanelsStream(locId).listen((ps) {
        if (mounted) {
          setState(() {
            _panels = ps;
          });
        }
      });
    }
  }

  Map<String, String> _getInstructions() {
    switch (widget.collectionId) {
      case 'locations':
        return {
          'Cols': 'id, name, description',
          'Note': 'Physical Area (e.g. BF1-RMHS). Provide human-readable ID, Name, and optional Description.'
        };
      case 'panel_rooms':
        return {
          'Cols': 'id, name, description, locationId',
          'Note': 'Substation room (e.g. MCC-ROOM-2). Link to Physical Area via locationId.'
        };
      case 'panels':
        return {
          'Cols': 'id, name, type, description, panelRoomId, voltageLevel, busSections',
          'Note': 'Valid types: MCC, PCC, LDB, Control Panel. voltageLevel (e.g. 415V, 3.3kV, 11kV), busSections (e.g. MAIN or SEC-1 & 2).'
        };
      case 'feeders':
        return {
          'Cols': 'id, name, type, description, panelId, busSection, operatingState, upstreamFeederId',
          'Note': 'Valid types: Feeder, Spare, Incomer, Bus Coupler, Tie. busSection (MAIN, SEC-1, SEC-2), operatingState (CLOSED/OPEN).'
        };
      case 'transformers':
        return {
          'Cols': 'id, name, windingType, ratingKva, primaryVoltage, secondaryVoltage, tertiaryVoltage, primarySourceFeederId, locationId',
          'Note': 'Step-down distribution transformers. locationId refers to outdoor Switchyard Area (e.g. SUBSTATION-YARD).'
        };
      case 'master_equipments':
        return {
          'Cols': 'id, name, type, description, locationId, panelRoomId, panelId, feederId',
          'Note': 'Equipment tag goes into the id column. Link to locationId, panelRoomId, panelId, and feederId.'
        };
      case 'fault_types':
        return {
          'Cols': 'Fault_Code, Fault_Name, Discipline, Target_Equipment, Default_Severity, Target_SLA_Hours, Diagnostic_Checks, Corrective_Action, Plant_ID (Opt), Unit_ID (Opt)',
          'Note': 'Comprehensive Master Fault Types Catalog:\n'
              '• Fault_Code: Standard code (e.g. FT-CON-01, FT-VFD-01, FT-MOT-01)\n'
              '• Fault_Name: Diagnostic fault title (e.g. Contactor Welded Contacts, VFD Overcurrent Trip)\n'
              '• Discipline: Electrical, Mechanical, Instrumentation, Automation\n'
              '• Target_Equipment: Applicable components (e.g. Contactors, VFDs, Brakes, Motors, Pumps)\n'
              '• Default_Severity: Critical, Major, Moderate, Minor\n'
              '• Target_SLA_Hours: Resolution target SLA in hours (e.g. 1, 2, 4)\n'
              '• Diagnostic_Checks: Field troubleshooting steps & testing guide\n'
              '• Corrective_Action: Standard SOP replacement & repair procedure\n'
              '• Plant_ID / Unit_ID: Optional (leave blank or GLOBAL to inherit currently selected plant scope)'
        };
      case 'odc':
      case 'odc_causes':
        return {
          'Cols': 'ODC_ID, Discipline, Equipment_Category, Object_Part, Damage_Mode, Root_Cause, ISO_14224_Code, Severity, Recommended_Action, Plant_ID (Opt), Unit_ID (Opt)',
          'Note': 'ISO 14224 Industrial Failure Catalog (Object-Damage-Cause tri-axial standard):\n'
              '• ODC_ID: Unique identifier (e.g. ODC-CON-01, ODC-VFD-01, ODC-BRK-01)\n'
              '• Discipline: Electrical, Mechanical, Instrumentation, Automation\n'
              '• Equipment_Category: Contactor, Brakes, VFD, Soft Starter, Motor, Pump, Gearbox, etc.\n'
              '• Object_Part: Component part (e.g. Main Contacts, Brake Lining, IGBT Module, DE Bearing)\n'
              '• Damage_Mode: Physical manifestation (e.g. Contacts Welded, Lining Worn Out, High Vibration)\n'
              '• Root_Cause: Fundamental failure mechanism (e.g. Inrush Arcing, Cyclic Fatigue, Overload)\n'
              '• ISO_14224_Code: Standard failure mechanism code (e.g. E-3.1, M-3.1, E-7.1)\n'
              '• Severity: Critical, Major, Moderate, Minor\n'
              '• Recommended_Action: SOP action to restore equipment and prevent recurrence\n'
              '• Plant_ID / Unit_ID: Optional (leave blank or GLOBAL to inherit currently selected plant scope)'
        };
      case 'combined_hierarchy':
      default:
        return {
          'Cols': 'Physical Areas, Panel Rooms, Panels / MCCs, Feeders, Transformers, Master Equipment',
          'Note': 'Upload an All-in-One 6-sheet Master Excel file or single level sheets.\n• Sheet 1: Physical Areas (id, name, description)\n• Sheet 2: Panel Rooms (id, name, description, locationId)\n• Sheet 3: Panels / MCCs (id, name, type, description, panelRoomId, voltageLevel, busSections)\n• Sheet 4: Feeders (id, name, type, description, panelId, busSection, operatingState, upstreamFeederId)\n• Sheet 5: Transformers (id, name, windingType, ratingKva, primaryVoltage, secondaryVoltage, tertiaryVoltage, primarySourceFeederId, locationId)\n• Sheet 6: Master Equipment (id, name, type, description, locationId, panelRoomId, panelId, feederId)\n* Existing live unit data is pre-populated when you download templates!'
        };
    }
  }

  Future<void> _downloadTemplate() async {
    if (widget.collectionId == 'fault_types') {
      _downloadHierarchyTemplate('fault_types');
      return;
    }
    if (widget.collectionId == 'odc' || widget.collectionId == 'odc_causes') {
      _downloadHierarchyTemplate('odc');
      return;
    }
    _showHierarchyTemplateModal();
  }

  Future<void> _downloadHierarchyTemplate(String type) async {
    if (_userUnitId == null || _userPlantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Select scope first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

      // 1. Locations (Physical Areas) - No 'type' column!
      if (type == 'all' || type == 'location' || (widget.collectionId == 'locations' && type == 'single')) {
        final isSingle = type == 'location' || (widget.collectionId == 'locations' && type == 'single');
        final sheetName = isSingle ? 'Locations_Template' : 'Physical Areas';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet locSheet = excel[sheetName];
        final locCols = ['id', 'name', 'description'];
        locSheet.appendRow(locCols.map((e) => TextCellValue(e)).toList());

        final locSnap = await FirebaseFirestore.instance
            .collection('locations')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (locSnap.docs.isNotEmpty) {
          for (final doc in locSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            locSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['description']?.toString() ?? ''),
            ]);
          }
        } else {
          locSheet.appendRow([TextCellValue('CAST-HOUSE'), TextCellValue('Blast Furnace Cast House Floor'), TextCellValue('Hot metal tapping floor')]);
          locSheet.appendRow([TextCellValue('SIZER-AREA'), TextCellValue('Primary Sizer & Screening Plant'), TextCellValue('Raw ore reduction area')]);
          locSheet.appendRow([TextCellValue('WTP-AREA'), TextCellValue('Water Treatment & Cooling Tower'), TextCellValue('Circulation pump station')]);
        }
      }

      // 2. Panel Rooms (Substations)
      if (type == 'all' || type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single')) {
        final isSingle = type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single');
        final sheetName = isSingle ? 'Panel_Rooms_Template' : 'Panel Rooms';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet prSheet = excel[sheetName];
        final prCols = ['id', 'name', 'description', 'locationId'];
        prSheet.appendRow(prCols.map((e) => TextCellValue(e)).toList());

        final prSnap = await FirebaseFirestore.instance
            .collection('panel_rooms')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (prSnap.docs.isNotEmpty) {
          for (final doc in prSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawLocId = data['locationId'] != null ? HierarchyService.stripPrefix(data['locationId'].toString(), _userPlantId!, _userUnitId!) : '';
            prSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawLocId),
            ]);
          }
        } else {
          prSheet.appendRow([TextCellValue('MCC-ROOM-01'), TextCellValue('Main Cast House MCC Room 1'), TextCellValue('Substation 1 housing main drives'), TextCellValue('CAST-HOUSE')]);
          prSheet.appendRow([TextCellValue('MCC-ROOM-02'), TextCellValue('Secondary Sizer MCC Room 2'), TextCellValue('Substation 2 housing sizers'), TextCellValue('SIZER-AREA')]);
          prSheet.appendRow([TextCellValue('WTP-ELEC-ROOM'), TextCellValue('WTP Electrical Control Room'), TextCellValue('Water treatment substation'), TextCellValue('WTP-AREA')]);
        }
      }

      // 3. Panels (MCCs / PCCs)
      if (type == 'all' || type == 'panel' || (widget.collectionId == 'panels' && type == 'single')) {
        final isSingle = type == 'panel' || (widget.collectionId == 'panels' && type == 'single');
        final sheetName = isSingle ? 'Panels_Template' : 'Panels';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet pnlSheet = excel[sheetName];
        final pnlCols = ['id', 'name', 'type', 'description', 'panelRoomId', 'voltageLevel', 'busSections'];
        pnlSheet.appendRow(pnlCols.map((e) => TextCellValue(e)).toList());

        final pnlSnap = await FirebaseFirestore.instance
            .collection('panels')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (pnlSnap.docs.isNotEmpty) {
          for (final doc in pnlSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawPrId = data['panelRoomId'] != null ? HierarchyService.stripPrefix(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!) : '';
            final busSec = HierarchyService.formatBusSectionsForDisplay(data['busSections']);
            pnlSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'MCC'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawPrId),
              TextCellValue(data['voltageLevel']?.toString() ?? '415V'),
              TextCellValue(busSec),
            ]);
          }
        } else {
          pnlSheet.appendRow([TextCellValue('MCC-01'), TextCellValue('415V Cast House Main MCC Panel 1'), TextCellValue('MCC'), TextCellValue('Fed from TR-1'), TextCellValue('MCC-ROOM-01'), TextCellValue('415V'), TextCellValue('MAIN')]);
          pnlSheet.appendRow([TextCellValue('MCC-02'), TextCellValue('415V Sizer Drives MCC Panel 2'), TextCellValue('MCC'), TextCellValue('Fed from TR-2'), TextCellValue('MCC-ROOM-02'), TextCellValue('415V'), TextCellValue('MAIN')]);
          pnlSheet.appendRow([TextCellValue('415V-LT-PCC1'), TextCellValue('415V Main Power Control Center 1'), TextCellValue('PCC'), TextCellValue('Split bus switchboard'), TextCellValue('MCC-ROOM-01'), TextCellValue('415V'), TextCellValue('SEC-1 & 2')]);
        }
      }

      // 4. Feeders
      if (type == 'all' || type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single')) {
        final isSingle = type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single');
        final sheetName = isSingle ? 'Feeders_Template' : 'Feeders';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet fdrSheet = excel[sheetName];
        final fdrCols = ['id', 'name', 'type', 'description', 'panelId', 'busSection', 'operatingState', 'upstreamFeederId'];
        fdrSheet.appendRow(fdrCols.map((e) => TextCellValue(e)).toList());

        final fdrSnap = await FirebaseFirestore.instance
            .collection('feeders')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (fdrSnap.docs.isNotEmpty) {
          for (final doc in fdrSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawPnlId = data['panelId'] != null ? HierarchyService.stripPrefix(data['panelId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawUpFdrId = data['upstreamFeederId'] != null ? HierarchyService.stripPrefix(data['upstreamFeederId'].toString(), _userPlantId!, _userUnitId!) : '';
            fdrSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'Feeder'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawPnlId),
              TextCellValue(HierarchyService.normalizeFeederBusSection(data['busSection'])),
              TextCellValue(data['operatingState']?.toString() ?? 'CLOSED'),
              TextCellValue(rawUpFdrId),
            ]);
          }
        } else {
          fdrSheet.appendRow([TextCellValue('INCOMER-1'), TextCellValue('1600A Incomer ACB Feeder 1'), TextCellValue('Incomer'), TextCellValue('From 2MVA Transformer 1'), TextCellValue('415V-LT-PCC1'), TextCellValue('SEC-1'), TextCellValue('CLOSED'), TextCellValue('TR-5.5MVA-1')]);
          fdrSheet.appendRow([TextCellValue('PCC1-BC-01'), TextCellValue('Bus Coupler BC-01'), TextCellValue('Bus Coupler'), TextCellValue('Couples Section 1 & 2'), TextCellValue('415V-LT-PCC1'), TextCellValue('SEC-1 & 2'), TextCellValue('OPEN'), TextCellValue('')]);
          fdrSheet.appendRow([TextCellValue('SIZER-MTR-FDR'), TextCellValue('160A Sizer Drive Feeder'), TextCellValue('Feeder'), TextCellValue('Sizer motor module'), TextCellValue('MCC-02'), TextCellValue('MAIN'), TextCellValue('CLOSED'), TextCellValue('')]);
        }
      }

      // 5. Transformers
      if (type == 'all' || type == 'transformer' || (widget.collectionId == 'transformers' && type == 'single')) {
        final isSingle = type == 'transformer' || (widget.collectionId == 'transformers' && type == 'single');
        final sheetName = isSingle ? 'Transformers_Template' : 'Transformers';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet trSheet = excel[sheetName];
        final trCols = ['id', 'name', 'windingType', 'ratingKva', 'primaryVoltage', 'secondaryVoltage', 'tertiaryVoltage', 'primarySourceFeederId', 'secondaryTargetPanelId', 'tertiaryTargetPanelId', 'locationId'];
        trSheet.appendRow(trCols.map((e) => TextCellValue(e)).toList());

        final trSnap = await FirebaseFirestore.instance
            .collection('transformers')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (trSnap.docs.isNotEmpty) {
          for (final doc in trSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawLocId = data['locationId'] != null ? HierarchyService.stripPrefix(data['locationId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawFdrId = data['primarySourceFeederId'] != null ? HierarchyService.stripPrefix(data['primarySourceFeederId'].toString(), _userPlantId!, _userUnitId!) : '';
            trSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['windingType']?.toString() ?? 'two_winding'),
              TextCellValue(data['ratingKva']?.toString() ?? '1000'),
              TextCellValue(data['primaryVoltage']?.toString() ?? '11kV'),
              TextCellValue(data['secondaryVoltage']?.toString() ?? '415V'),
              TextCellValue(data['tertiaryVoltage']?.toString() ?? ''),
              TextCellValue(rawFdrId),
              TextCellValue(rawLocId),
            ]);
          }
        } else {
          trSheet.appendRow([
            TextCellValue('TR-5.5MVA-1'),
            TextCellValue('5.5MVA Transformer 1'),
            TextCellValue('three_winding'),
            TextCellValue('5500'),
            TextCellValue('11kV'),
            TextCellValue('3.3kV'),
            TextCellValue('415V'),
            TextCellValue('HTPCC-OG-TR-55-1'),
            TextCellValue('SUBSTATION-YARD'),
          ]);
        }
      }

      // 5. Master Equipment
      if (type == 'all' || type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single')) {
        final isSingle = type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single');
        final sheetName = isSingle ? 'Master_Equipment_Template' : 'Master Equipment';
        if (isSingle && excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet meSheet = excel[sheetName];
        final meCols = ['id', 'name', 'type', 'description', 'locationId', 'panelRoomId', 'panelId', 'feederId'];
        meSheet.appendRow(meCols.map((e) => TextCellValue(e)).toList());

        final meSnap = await FirebaseFirestore.instance
            .collection('master_equipments')
            .where('plantId', isEqualTo: _userPlantId)
            .where('unitId', isEqualTo: _userUnitId)
            .get();

        if (meSnap.docs.isNotEmpty) {
          for (final doc in meSnap.docs) {
            final data = doc.data();
            final rawId = HierarchyService.stripPrefix(doc.id, _userPlantId!, _userUnitId!);
            final rawLocId = data['locationId'] != null ? HierarchyService.stripPrefix(data['locationId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawPrId = data['panelRoomId'] != null ? HierarchyService.stripPrefix(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawPnlId = data['panelId'] != null ? HierarchyService.stripPrefix(data['panelId'].toString(), _userPlantId!, _userUnitId!) : '';
            final rawFdrId = data['feederId'] != null ? HierarchyService.stripPrefix(data['feederId'].toString(), _userPlantId!, _userUnitId!) : '';

            meSheet.appendRow([
              TextCellValue(rawId),
              TextCellValue(data['name']?.toString() ?? ''),
              TextCellValue(data['type']?.toString() ?? 'Machinery'),
              TextCellValue(data['description']?.toString() ?? ''),
              TextCellValue(rawLocId),
              TextCellValue(rawPrId),
              TextCellValue(rawPnlId),
              TextCellValue(rawFdrId),
            ]);
          }
        } else {
          meSheet.appendRow([
            TextCellValue('BF1-SIZER-01'),
            TextCellValue('Primary Sizer Machine 1'),
            TextCellValue('Crushing & Sizing'),
            TextCellValue('Heavy duty mineral sizer'),
            TextCellValue('SIZER-AREA'),
            TextCellValue('MCC-ROOM-02'),
            TextCellValue('MCC-02'),
            TextCellValue('SIZER-MTR-FDR'),
          ]);
          meSheet.appendRow([
            TextCellValue('BF1-CH-CRANE-01'),
            TextCellValue('Cast House 60T Hot Metal Crane 1'),
            TextCellValue('EOT Crane'),
            TextCellValue('60/10T Cast house crane'),
            TextCellValue('CAST-HOUSE'),
            TextCellValue('MCC-ROOM-01'),
            TextCellValue('MCC-01'),
            TextCellValue('CRANE-BUS-FDR'),
          ]);
        }
      }

      // 6. Fault Types
      if (type == 'fault_types' || widget.collectionId == 'fault_types') {
        final sheetName = 'Fault_Types_Master';
        if (excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet ftSheet = excel[sheetName];
        final ftCols = [
          'Fault_Code', 'Fault_Name', 'Discipline', 'Target_Equipment',
          'Default_Severity', 'Target_SLA_Hours', 'Diagnostic_Checks', 'Corrective_Action',
          'Plant_ID', 'Unit_ID'
        ];
        ftSheet.appendRow(ftCols.map((e) => TextCellValue(e)).toList());

        final ftSnap = await FirebaseFirestore.instance.collection('fault_types').limit(100).get();
        if (ftSnap.docs.isNotEmpty) {
          for (final doc in ftSnap.docs) {
            final data = doc.data();
            ftSheet.appendRow([
              TextCellValue(data['Fault_Code']?.toString() ?? data['faultCode']?.toString() ?? doc.id),
              TextCellValue(data['Fault_Name']?.toString() ?? data['faultName']?.toString() ?? data['name']?.toString() ?? ''),
              TextCellValue(data['Discipline']?.toString() ?? data['discipline']?.toString() ?? data['category']?.toString() ?? 'Electrical'),
              TextCellValue(data['Target_Equipment']?.toString() ?? data['targetEquipment']?.toString() ?? data['equipmentType']?.toString() ?? ''),
              TextCellValue(data['Default_Severity']?.toString() ?? data['severity']?.toString() ?? 'Critical'),
              TextCellValue(data['Target_SLA_Hours']?.toString() ?? data['targetSlaHours']?.toString() ?? '2'),
              TextCellValue(data['Diagnostic_Checks']?.toString() ?? data['diagnosticChecks']?.toString() ?? ''),
              TextCellValue(data['Corrective_Action']?.toString() ?? data['correctiveAction']?.toString() ?? ''),
              TextCellValue(data['Plant_ID']?.toString() ?? data['plantId']?.toString() ?? _userPlantId ?? 'GLOBAL'),
              TextCellValue(data['Unit_ID']?.toString() ?? data['unitId']?.toString() ?? _userUnitId ?? 'GLOBAL'),
            ]);
          }
        } else {
          ftSheet.appendRow([
            TextCellValue('FT-CON-01'), TextCellValue('Contactor Welded / Pitted Contacts'),
            TextCellValue('Electrical'), TextCellValue('Contactors, Motor Feeders'),
            TextCellValue('Critical'), TextCellValue('1'),
            TextCellValue('Measure contact continuity across poles; inspect silver tip puddle'),
            TextCellValue('Replace contact pole kit / contactor unit; check motor FLC'),
            TextCellValue(_userPlantId ?? 'GLOBAL'), TextCellValue(_userUnitId ?? 'GLOBAL'),
          ]);
          ftSheet.appendRow([
            TextCellValue('FT-VFD-01'), TextCellValue('VFD Inverter Overcurrent Trip (F001)'),
            TextCellValue('Electrical'), TextCellValue('Variable Frequency Drives (VFD)'),
            TextCellValue('Critical'), TextCellValue('1'),
            TextCellValue('Megger motor cable; test IGBT module for collector-emitter short'),
            TextCellValue('Replace faulty IGBT / VFD unit; verify motor insulation & dV/dt filter'),
            TextCellValue(_userPlantId ?? 'GLOBAL'), TextCellValue(_userUnitId ?? 'GLOBAL'),
          ]);
        }
      }

      // 7. ODC Causes
      if (type == 'odc' || type == 'odc_causes' || widget.collectionId == 'odc' || widget.collectionId == 'odc_causes') {
        final sheetName = 'ODC_Master';
        if (excel.sheets.containsKey(defaultSheet)) {
          excel.rename(defaultSheet, sheetName);
        }
        Sheet odcSheet = excel[sheetName];
        final odcCols = [
          'ODC_ID', 'Discipline', 'Equipment_Category', 'Object_Part',
          'Damage_Mode', 'Root_Cause', 'ISO_14224_Code', 'Severity',
          'Recommended_Action', 'Plant_ID', 'Unit_ID'
        ];
        odcSheet.appendRow(odcCols.map((e) => TextCellValue(e)).toList());

        var odcSnap = await FirebaseFirestore.instance.collection('odc').limit(100).get();
        if (odcSnap.docs.isEmpty) {
          odcSnap = await FirebaseFirestore.instance.collection('odc_causes').limit(100).get();
        }
        if (odcSnap.docs.isNotEmpty) {
          for (final doc in odcSnap.docs) {
            final data = doc.data();
            odcSheet.appendRow([
              TextCellValue(data['ODC_ID']?.toString() ?? data['odcId']?.toString() ?? doc.id),
              TextCellValue(data['Discipline']?.toString() ?? data['discipline']?.toString() ?? data['category']?.toString() ?? 'Electrical'),
              TextCellValue(data['Equipment_Category']?.toString() ?? data['equipmentCategory']?.toString() ?? ''),
              TextCellValue(data['Object_Part']?.toString() ?? data['objectPart']?.toString() ?? ''),
              TextCellValue(data['Damage_Mode']?.toString() ?? data['damageMode']?.toString() ?? data['damage']?.toString() ?? ''),
              TextCellValue(data['Root_Cause']?.toString() ?? data['rootCause']?.toString() ?? data['cause']?.toString() ?? data['name']?.toString() ?? ''),
              TextCellValue(data['ISO_14224_Code']?.toString() ?? data['isoCode']?.toString() ?? ''),
              TextCellValue(data['Severity']?.toString() ?? data['severity']?.toString() ?? 'Critical'),
              TextCellValue(data['Recommended_Action']?.toString() ?? data['recommendedAction']?.toString() ?? ''),
              TextCellValue(data['Plant_ID']?.toString() ?? data['plantId']?.toString() ?? _userPlantId ?? 'GLOBAL'),
              TextCellValue(data['Unit_ID']?.toString() ?? data['unitId']?.toString() ?? _userUnitId ?? 'GLOBAL'),
            ]);
          }
        } else {
          odcSheet.appendRow([
            TextCellValue('ODC-CON-01'), TextCellValue('Electrical'), TextCellValue('Contactor'),
            TextCellValue('Main Power Contacts / Tips'), TextCellValue('Contacts Welded / Fused Together'),
            TextCellValue('High Inrush Current / Mechanical Jam in Load'), TextCellValue('E-3.1'),
            TextCellValue('Critical'), TextCellValue('Replace contactor power pole kit; inspect motor load for locked rotor'),
            TextCellValue(_userPlantId ?? 'GLOBAL'), TextCellValue(_userUnitId ?? 'GLOBAL'),
          ]);
          odcSheet.appendRow([
            TextCellValue('ODC-BRK-01'), TextCellValue('Mechanical'), TextCellValue('Industrial Brake'),
            TextCellValue('Brake Shoe Friction Lining'), TextCellValue('Lining Worn Out to Rivet Level'),
            TextCellValue('Normal Friction Wear / High Braking Frequency'), TextCellValue('M-3.1'),
            TextCellValue('Critical'), TextCellValue('Replace woven non-asbestos friction lining; adjust brake clearance'),
            TextCellValue(_userPlantId ?? 'GLOBAL'), TextCellValue(_userUnitId ?? 'GLOBAL'),
          ]);
        }
      }

      // 8. Reference Guide Sheet
      if (type == 'all') {
        Sheet refSheet = excel['Reference_Guide'];
        refSheet.appendRow([TextCellValue('HIERARCHY MASTER DATA STRUCTURE & LINKING GUIDE')]);
        refSheet.appendRow([TextCellValue('Tier'), TextCellValue('Sheet Name'), TextCellValue('ID Tag Format'), TextCellValue('Parent Link Column'), TextCellValue('Description')]);
        refSheet.appendRow([TextCellValue('Tier 1'), TextCellValue('Physical Areas'), TextCellValue('CAST-HOUSE, SIZER-AREA'), TextCellValue('N/A (Root)'), TextCellValue('Geographical or functional plant zone')]);
        refSheet.appendRow([TextCellValue('Tier 2'), TextCellValue('Panel Rooms'), TextCellValue('MCC-ROOM-01'), TextCellValue('locationId (Optional)'), TextCellValue('Substation, Switchgear or MCC Room')]);
        refSheet.appendRow([TextCellValue('Tier 3'), TextCellValue('Panels'), TextCellValue('MCC-01, PCC-01, LDB-01'), TextCellValue('panelRoomId'), TextCellValue('Switchboard, MCC or PCC distribution panel')]);
        refSheet.appendRow([TextCellValue('Tier 4'), TextCellValue('Feeders'), TextCellValue('INCOMER-1, FDR-01'), TextCellValue('panelId'), TextCellValue('Breaker, module, starter or outgoer feeder')]);
        refSheet.appendRow([TextCellValue('Tier 5'), TextCellValue('Master Equipment'), TextCellValue('BF1-SIZER-01, CRANE-01'), TextCellValue('locationId, panelRoomId, panelId, feederId'), TextCellValue('Physical machine tag holding electrical/mechanical assets')]);
      }

      final filename = type == 'fault_types' || (widget.collectionId == 'fault_types')
          ? 'Fault_Types_Template.xlsx'
          : type == 'odc' || type == 'odc_causes' || (widget.collectionId == 'odc' || widget.collectionId == 'odc_causes')
              ? 'ODC_Causes_Template.xlsx'
              : type == 'location' || (widget.collectionId == 'locations' && type == 'single')
                  ? 'Physical_Areas_Template.xlsx'
                  : type == 'panel_room' || (widget.collectionId == 'panel_rooms' && type == 'single')
                      ? 'Panel_Rooms_Template.xlsx'
                      : type == 'panel' || (widget.collectionId == 'panels' && type == 'single')
                          ? 'Panels_MCC_Template.xlsx'
                          : type == 'feeder' || (widget.collectionId == 'feeders' && type == 'single')
                              ? 'Feeders_Template.xlsx'
                              : type == 'master_equipment' || (widget.collectionId == 'master_equipments' && type == 'single')
                                  ? 'Master_Equipment_Template.xlsx'
                                  : 'Hierarchy_Master_All_In_One.xlsx';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final savedPath = await downloadFile(fileBytes, filename);
        if (mounted) {
          if (savedPath != null) {
            _showDownloadSuccessDialog(savedPath, filename);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template generated successfully!'), 
                backgroundColor: AppColors.success, 
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating hierarchy template: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showDownloadSuccessDialog(String path, String fileName) {
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
              Text('Template Exported', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    await Share.shareXFiles([XFile(path)], text: 'Hierarchy Template: $fileName');
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
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final result = await OpenFile.open(path);
                    if (result.type != ResultType.done) {
                      messenger.showSnackBar(
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

  void _showHierarchyTemplateModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Choose Hierarchy Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Download tailored Excel templates populated with your live unit database records for editing and re-import:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.map, color: Colors.indigoAccent),
                ),
                title: const Text('Physical Areas (Locations) Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 1: Geographic plant zones (ID, Name, Description)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.indigoAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('location');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.room_preferences, color: Colors.deepPurpleAccent),
                ),
                title: const Text('Panel Rooms (Substations) Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 2: Substation switchgear rooms (ID, Name, Description, Location Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.deepPurpleAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('panel_room');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.electric_bolt, color: Colors.amberAccent),
                ),
                title: const Text('Panels / MCCs Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 3: MCCs, PCCs, LDBs (ID, Name, Type, Description, Panel Room Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.amberAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('panel');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.power_input, color: Colors.cyanAccent),
                ),
                title: const Text('Feeders Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 4: Incomer, Outgoer, Starter Feeders (ID, Name, Type, Panel Link, Section, State)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.cyanAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('feeder');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.electrical_services, color: Colors.purpleAccent),
                ),
                title: const Text('Transformers Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 5: Step-down transformers in switchyard (ID, Ratings, Voltages, HT Feeder Link)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.purpleAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('transformer');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.precision_manufacturing, color: Colors.orangeAccent),
                ),
                title: const Text('Master Equipment Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tier 6: Machine tags linked to Location, Panel Room, Panel, Feeder', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.orangeAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('master_equipment');
                },
              ),
              const Divider(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.table_chart, color: Colors.greenAccent),
                ),
                title: const Text('All-in-One Master Hierarchy Workbook (6 Sheets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Contains all 6 levels (Areas, Rooms, Panels, Feeders, Transformers, Machines)', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.download, size: 18, color: Colors.greenAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadHierarchyTemplate('all');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _validateImportData(List<Map<String, dynamic>> rawData) async {
    if (_userPlantId == null || _userUnitId == null) return rawData;

    final List<Map<String, dynamic>> enriched = [];

    // Pre-fetch existing documents for validation
    final locs = await FirebaseFirestore.instance.collection('locations').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownLocIds = {};
    for (var d in locs.docs) {
      knownLocIds.add(d.id.toUpperCase());
      knownLocIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final prs = await FirebaseFirestore.instance.collection('panel_rooms').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownPrIds = {};
    for (var d in prs.docs) {
      knownPrIds.add(d.id.toUpperCase());
      knownPrIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final pnls = await FirebaseFirestore.instance.collection('panels').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownPnlIds = {};
    for (var d in pnls.docs) {
      knownPnlIds.add(d.id.toUpperCase());
      knownPnlIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final fdrs = await FirebaseFirestore.instance.collection('feeders').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownFdrIds = {};
    for (var d in fdrs.docs) {
      knownFdrIds.add(d.id.toUpperCase());
      knownFdrIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final eqs = await FirebaseFirestore.instance.collection('master_equipments').where('plantId', isEqualTo: _userPlantId).where('unitId', isEqualTo: _userUnitId).get();
    final Set<String> knownEqIds = {};
    for (var d in eqs.docs) {
      knownEqIds.add(d.id.toUpperCase());
      knownEqIds.add(HierarchyService.stripPrefix(d.id, _userPlantId!, _userUnitId!).toUpperCase());
    }

    final Set<String> knownFtIds = {};
    if (widget.collectionId == 'fault_types' || widget.collectionId == 'combined_hierarchy') {
      final fts = await FirebaseFirestore.instance.collection('fault_types').get();
      for (var d in fts.docs) {
        knownFtIds.add(d.id.toUpperCase());
      }
    }

    final Set<String> knownOdcIds = {};
    if (widget.collectionId == 'odc' || widget.collectionId == 'odc_causes' || widget.collectionId == 'combined_hierarchy') {
      final odcs = await FirebaseFirestore.instance.collection('odc').get();
      for (var d in odcs.docs) {
        knownOdcIds.add(d.id.toUpperCase());
      }
      final legacyOdcs = await FirebaseFirestore.instance.collection('odc_causes').get();
      for (var d in legacyOdcs.docs) {
        knownOdcIds.add(d.id.toUpperCase());
      }
    }

    final Map<String, Set<String>> seenInFileIds = {};

    for (final rawRow in rawData) {
      final Map<String, dynamic> row = Map.from(rawRow);

      final target = row['_collection']?.toString().trim() ?? '';
      final sheet = row['_sheetName']?.toString().toLowerCase().trim() ?? '';

      String coll = target;
      if (coll.isEmpty) {
        if (widget.collectionId != 'combined_hierarchy') {
          coll = widget.collectionId;
        } else if (sheet.contains('location') || sheet.contains('area') || sheet.contains('physical')) {
          coll = 'locations';
        } else if (sheet.contains('room') || sheet.contains('substation')) {
          coll = 'panel_rooms';
        } else if (sheet.contains('panel') || sheet.contains('mcc') || sheet.contains('pcc')) {
          coll = 'panels';
        } else if (sheet.contains('feeder')) {
          coll = 'feeders';
        } else if (sheet.contains('transformer')) {
          coll = 'transformers';
        } else if (sheet.contains('equipment') || sheet.contains('machin') || sheet.contains('master')) {
          coll = 'master_equipments';
        } else {
          if (row.containsKey('feederId') || (row.containsKey('locationId') && row.containsKey('panelId'))) {
            coll = 'master_equipments';
          } else if (row.containsKey('panelId') && !row.containsKey('feederId')) {
            coll = 'feeders';
          } else if (row.containsKey('panelRoomId') && !row.containsKey('feederId')) {
            coll = 'panels';
          } else if (row.containsKey('locationId') && !row.containsKey('panelRoomId')) {
            coll = 'panel_rooms';
          } else {
            coll = 'locations';
          }
        }
      }
      row['_collection'] = coll;

      final rawId = (row['id'] ?? 
                     row['ODC_ID'] ?? 
                     row['odc_id'] ?? 
                     row['Fault_Code'] ?? 
                     row['fault_code'] ?? 
                     row['faultCode'] ?? 
                     row['tagId'] ?? 
                     row['tagNo'])?.toString().trim() ?? '';
      final name = (row['name'] ?? 
                    row['Fault_Name'] ?? 
                    row['fault_name'] ?? 
                    row['faultName'] ?? 
                    row['Root_Cause'] ?? 
                    row['Damage_Mode'] ?? 
                    row['damage'])?.toString().trim() ?? '';

      String status = 'OK';
      if (rawId.isEmpty) {
        status = 'Error: ID / Tag is missing.';
      } else if (name.isEmpty) {
        status = 'Warning: Name is blank.';
      } else {
        final fullId = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
        final upperRaw = rawId.toUpperCase();
        final upperFull = fullId.toUpperCase();

        seenInFileIds.putIfAbsent(coll, () => <String>{});
        if (seenInFileIds[coll]!.contains(upperRaw)) {
          status = 'Error: Duplicate ID "$rawId" found in sheet! Each ID must be strictly unique.';
        } else {
          seenInFileIds[coll]!.add(upperRaw);

          if (coll == 'locations') {
            if (knownLocIds.contains(upperFull) || knownLocIds.contains(upperRaw)) {
              status = 'Warning: Area "$rawId" exists. Will update.';
            }
            knownLocIds.add(upperFull);
            knownLocIds.add(upperRaw);
          } else if (coll == 'panel_rooms') {
            if (knownPrIds.contains(upperFull) || knownPrIds.contains(upperRaw)) {
              status = 'Warning: Panel Room "$rawId" exists. Will update.';
            }
            final locId = row['locationId']?.toString().trim() ?? '';
            if (locId.isNotEmpty) {
              final fullLoc = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!).toUpperCase();
              if (!knownLocIds.contains(fullLoc) && !knownLocIds.contains(locId.toUpperCase())) {
                status = 'Info: Linked Location "$locId" (will resolve).';
              }
            }
            knownPrIds.add(upperFull);
            knownPrIds.add(upperRaw);
          } else if (coll == 'panels') {
            if (knownPnlIds.contains(upperFull) || knownPnlIds.contains(upperRaw)) {
              status = 'Warning: Panel "$rawId" exists. Will update.';
            }
            final prId = row['panelRoomId']?.toString().trim() ?? '';
            if (prId.isNotEmpty) {
              final fullPr = HierarchyService.prefixId(prId, _userPlantId!, _userUnitId!).toUpperCase();
              if (!knownPrIds.contains(fullPr) && !knownPrIds.contains(prId.toUpperCase())) {
                status = 'Warning: Panel Room "$prId" not found in batch or unit.';
              }
            } else if (_selectedLocationId == null && widget.collectionId == 'panels') {
              status = 'Error: Select Panel Room in header or specify in panelRoomId column.';
            }
            knownPnlIds.add(upperFull);
            knownPnlIds.add(upperRaw);
          } else if (coll == 'feeders') {
            if (knownFdrIds.contains(upperFull) || knownFdrIds.contains(upperRaw)) {
              status = 'Warning: Feeder "$rawId" exists. Will update.';
            }
            final pId = row['panelId']?.toString().trim() ?? '';
            if (pId.isNotEmpty) {
              final fullP = HierarchyService.prefixId(pId, _userPlantId!, _userUnitId!).toUpperCase();
              if (!knownPnlIds.contains(fullP) && !knownPnlIds.contains(pId.toUpperCase())) {
                status = 'Warning: Panel "$pId" not found in batch or unit.';
              }
            } else if (_selectedPanelId == null && widget.collectionId == 'feeders') {
              status = 'Error: Select Panel in header or specify in panelId column.';
            }
            knownFdrIds.add(upperFull);
            knownFdrIds.add(upperRaw);
          } else if (coll == 'transformers') {
            final locId = row['locationId']?.toString().trim() ?? '';
            if (locId.isNotEmpty) {
              final fullLoc = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!).toUpperCase();
              if (!knownLocIds.contains(fullLoc) && !knownLocIds.contains(locId.toUpperCase())) {
                status = 'Info: Location "$locId" assigned.';
              }
            }
          } else if (coll == 'master_equipments') {
            if (knownEqIds.contains(upperFull) || knownEqIds.contains(upperRaw)) {
              status = 'Warning: Machine "$rawId" exists. Will update.';
            }
            final locId = row['locationId']?.toString().trim() ?? '';
            if (locId.isNotEmpty) {
              final fullLoc = HierarchyService.prefixId(locId, _userPlantId!, _userUnitId!).toUpperCase();
              if (!knownLocIds.contains(fullLoc) && !knownLocIds.contains(locId.toUpperCase())) {
                status = 'Info: Location "$locId" assigned.';
              }
            }
            knownEqIds.add(upperFull);
            knownEqIds.add(upperRaw);
          } else if (coll == 'fault_types') {
            if (knownFtIds.contains(upperRaw)) {
              status = 'Warning: Fault Type "$rawId" exists. Will update.';
            }
            knownFtIds.add(upperRaw);
          } else if (coll == 'odc' || coll == 'odc_causes') {
            if (knownOdcIds.contains(upperRaw)) {
              status = 'Warning: ODC Cause "$rawId" exists. Will update.';
            }
            knownOdcIds.add(upperRaw);
          }
        }
      }

      row['Validation'] = status;
      enriched.add(row);
    }

    return enriched;
  }

  Future<void> _pickFile() async {
    final isCatalog = widget.collectionId == 'fault_types' || widget.collectionId == 'odc' || widget.collectionId == 'odc_causes';
    if (!isCatalog && _userUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select scope (Plant & Unit) before choosing a file.')),
      );
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result.isNotEmpty) {
        final pickedFile = result.single;
        setState(() {
          _fileName = pickedFile.name;
          _isProcessing = true;
          _statusMessage = 'Parsing Excel...';
        });

        final fileBytes = await pickedFile.readAsBytes();

        var data = widget.collectionId == 'combined_hierarchy'
            ? _excelService.parseAllSheets(fileBytes)
            : _excelService.parseExcel(fileBytes);
        // Auto-fallback: if single sheet parse found nothing, attempt parseAllSheets
        if (data.isEmpty) {
          data = _excelService.parseAllSheets(fileBytes);
        }

        final validatedData = await _validateImportData(data);
        setState(() {
          _previewData = validatedData;
          _selectedPreviewTab = 'all';
          _statusMessage = data.isEmpty
              ? "Error: No data found in file."
              : "Parsed ${data.length} records. Please review warnings/errors below.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _upload() async {
    final hasErrors = _previewData.any((row) => row['Validation']?.toString().startsWith('Error') == true);
    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Resolve validation errors in the preview list before importing.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Uploading to Firestore...";
    });

    try {
      final List<Map<String, dynamic>> locList = [];
      final List<Map<String, dynamic>> prList = [];
      final List<Map<String, dynamic>> pnlList = [];
      final List<Map<String, dynamic>> fdrList = [];
      final List<Map<String, dynamic>> trList = [];
      final List<Map<String, dynamic>> meList = [];
      final List<Map<String, dynamic>> ftList = [];
      final List<Map<String, dynamic>> odcList = [];

      for (final raw in _previewData) {
        final data = Map<String, dynamic>.from(raw);
        data.remove('Validation');
        final target = data.remove('_collection')?.toString() ?? (widget.collectionId == 'combined_hierarchy' ? 'locations' : widget.collectionId);
        data.remove('_sheetName');

        final isCatalog = target == 'fault_types' || target == 'odc' || target == 'odc_causes';
        final resolvedPlant = (data['Plant_ID'] ?? data['plant_id'] ?? data['plantId'] ?? _userPlantId ?? 'GLOBAL').toString().trim().toUpperCase();
        final resolvedUnit = (data['Unit_ID'] ?? data['unit_id'] ?? data['unitId'] ?? _userUnitId ?? 'ALL').toString().trim().toUpperCase();
        data['plantId'] = resolvedPlant.isNotEmpty ? resolvedPlant : (_userPlantId ?? 'GLOBAL');
        data['unitId'] = (resolvedUnit.isNotEmpty && resolvedUnit != 'GLOBAL') ? resolvedUnit : (_userUnitId ?? 'ALL');
        data['Plant_ID'] = data['plantId'];
        data['Unit_ID'] = data['unitId'];

        final rawId = (data['id'] ?? 
                       data['ODC_ID'] ?? 
                       data['odc_id'] ?? 
                       data['Fault_Code'] ?? 
                       data['fault_code'] ?? 
                       data['faultCode'] ?? 
                       data['tagId'] ?? 
                       data['tagNo'])?.toString().trim() ?? '';
                       
        if (rawId.isNotEmpty) {
          if (isCatalog) {
            // Apply PLANT-UNIT prefix to catalog IDs to prevent duplicate collisions across units and plants
            final p = data['plantId']!.toString().trim().toUpperCase();
            final u = data['unitId']!.toString().trim().toUpperCase();
            data['id'] = HierarchyService.prefixId(rawId, p, u);
          } else {
            data['id'] = HierarchyService.prefixId(rawId, _userPlantId!, _userUnitId!);
          }
        }

        if (target == 'locations') {
          locList.add(data);
        } else if (target == 'panel_rooms') {
          if (data['locationId'] != null && data['locationId'].toString().isNotEmpty) {
            data['locationId'] = HierarchyService.prefixId(data['locationId'].toString(), _userPlantId!, _userUnitId!);
          }
          prList.add(data);
        } else if (target == 'panels') {
          final rawPr = data['panelRoomId']?.toString().trim();
          if (rawPr != null && rawPr.isNotEmpty) {
            data['panelRoomId'] = HierarchyService.prefixId(rawPr, _userPlantId!, _userUnitId!);
          } else if (_selectedLocationId != null) {
            data['panelRoomId'] = _selectedLocationId;
          }

          final rawLoc = data['locationId']?.toString().trim();
          if (rawLoc != null && rawLoc.isNotEmpty) {
            data['locationId'] = HierarchyService.prefixId(rawLoc, _userPlantId!, _userUnitId!);
          } else {
            // Automatically resolve locationId from parent panel room
            String? resolvedLoc;
            if (data['panelRoomId'] != null) {
              final prMatch = prList.firstWhere(
                (r) => r['id'] == data['panelRoomId'],
                orElse: () => <String, dynamic>{},
              );
              if (prMatch.isNotEmpty && prMatch['locationId'] != null) {
                resolvedLoc = prMatch['locationId']?.toString();
              }
            }
            data['locationId'] = resolvedLoc ?? data['panelRoomId'] ?? _selectedLocationId ?? '';
          }
          data['busSections'] = HierarchyService.parseBusSections(data['busSections']);
          if (data['voltageLevel'] == null || data['voltageLevel'].toString().isEmpty) {
            data['voltageLevel'] = '415V';
          }
          pnlList.add(data);
        } else if (target == 'feeders') {
          if (data['panelId'] == null || data['panelId'].toString().isEmpty) {
            if (_selectedPanelId != null) data['panelId'] = _selectedPanelId;
          } else {
            data['panelId'] = HierarchyService.prefixId(data['panelId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['upstreamFeederId'] != null && data['upstreamFeederId'].toString().isNotEmpty) {
            data['upstreamFeederId'] = HierarchyService.prefixId(data['upstreamFeederId'].toString(), _userPlantId!, _userUnitId!);
          }
          data['busSection'] = HierarchyService.normalizeFeederBusSection(data['busSection']);
          if (data['operatingState'] == null || data['operatingState'].toString().isEmpty) {
            data['operatingState'] = 'CLOSED';
          }
          fdrList.add(data);
        } else if (target == 'transformers') {
          if (data['primarySourceFeederId'] != null && data['primarySourceFeederId'].toString().isNotEmpty) {
            data['primarySourceFeederId'] = HierarchyService.prefixId(data['primarySourceFeederId'].toString(), _userPlantId!, _userUnitId!);
          }
          final secTgt = data['secondaryTargetPanelId'] ?? data['secondaryTargetId'];
          if (secTgt != null && secTgt.toString().isNotEmpty && secTgt.toString() != 'None') {
            data['secondaryTargetPanelId'] = HierarchyService.prefixId(secTgt.toString(), _userPlantId!, _userUnitId!);
          }
          final tertTgt = data['tertiaryTargetPanelId'] ?? data['tertiaryTargetId'];
          if (tertTgt != null && tertTgt.toString().isNotEmpty && tertTgt.toString() != 'None') {
            data['tertiaryTargetPanelId'] = HierarchyService.prefixId(tertTgt.toString(), _userPlantId!, _userUnitId!);
          }
          if (data['locationId'] != null && data['locationId'].toString().isNotEmpty) {
            data['locationId'] = HierarchyService.prefixId(data['locationId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['ratingKva'] != null) {
            data['ratingKva'] = double.tryParse(data['ratingKva'].toString()) ?? 1000.0;
          }
          trList.add(data);
        } else if (target == 'master_equipments' || target == 'master_equipment') {
          if (data['locationId'] == null || data['locationId'].toString().isEmpty) {
            if (_selectedLocationId != null) data['locationId'] = _selectedLocationId;
          } else {
            data['locationId'] = HierarchyService.prefixId(data['locationId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['panelRoomId'] != null && data['panelRoomId'].toString().isNotEmpty) {
            data['panelRoomId'] = HierarchyService.prefixId(data['panelRoomId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['panelId'] != null && data['panelId'].toString().isNotEmpty) {
            data['panelId'] = HierarchyService.prefixId(data['panelId'].toString(), _userPlantId!, _userUnitId!);
          }
          if (data['feederId'] != null && data['feederId'].toString().isNotEmpty) {
            data['feederId'] = HierarchyService.prefixId(data['feederId'].toString(), _userPlantId!, _userUnitId!);
          }
          meList.add(data);
        } else if (target == 'fault_types') {
          final code = (data['Fault_Code'] ?? data['fault_code'] ?? data['faultCode'] ?? data['id'] ?? rawId).toString().trim();
          final name = (data['Fault_Name'] ?? data['fault_name'] ?? data['faultName'] ?? data['name'] ?? '').toString().trim();
          final discipline = (data['Discipline'] ?? data['discipline'] ?? data['category'] ?? 'Electrical').toString().trim();
          final targetEq = (data['Target_Equipment'] ?? data['target_equipment'] ?? data['targetEquipment'] ?? data['equipmentType'] ?? '').toString().trim();
          final severity = (data['Default_Severity'] ?? data['severity'] ?? 'Major').toString().trim();
          final sla = data['Target_SLA_Hours'] ?? data['target_sla_hours'] ?? data['targetSlaHours'] ?? 4;
          final checks = (data['Diagnostic_Checks'] ?? data['diagnostic_checks'] ?? data['diagnosticChecks'] ?? '').toString().trim();
          final action = (data['Corrective_Action'] ?? data['corrective_action'] ?? data['correctiveAction'] ?? '').toString().trim();

          data['id'] = code;
          data['faultCode'] = code;
          data['Fault_Code'] = code;
          data['name'] = name;
          data['Fault_Name'] = name;
          data['category'] = discipline;
          data['discipline'] = discipline;
          data['Discipline'] = discipline;
          data['targetEquipment'] = targetEq;
          data['equipmentType'] = targetEq;
          data['Target_Equipment'] = targetEq;
          data['severity'] = severity;
          data['Default_Severity'] = severity;
          data['targetSlaHours'] = sla;
          data['Target_SLA_Hours'] = sla;
          data['diagnosticChecks'] = checks;
          data['Diagnostic_Checks'] = checks;
          data['correctiveAction'] = action;
          data['Corrective_Action'] = action;
          data['plantId'] = data['plantId'] ?? _userPlantId ?? 'GLOBAL';
          data['unitId'] = data['unitId'] ?? _userUnitId ?? 'GLOBAL';
          data['Plant_ID'] = data['plantId'];
          data['Unit_ID'] = data['unitId'];
          ftList.add(data);
        } else if (target == 'odc' || target == 'odc_causes') {
          final odcId = (data['id'] ?? data['ODC_ID'] ?? data['odc_id'] ?? data['odcId'] ?? rawId).toString().trim();
          final discipline = (data['Discipline'] ?? data['discipline'] ?? data['category'] ?? 'Electrical').toString().trim();
          final eqCategory = (data['Equipment_Category'] ?? data['equipment_category'] ?? data['equipmentCategory'] ?? '').toString().trim();
          final objPart = (data['Object_Part'] ?? data['object_part'] ?? data['objectPart'] ?? data['object'] ?? '').toString().trim();
          final damage = (data['Damage_Mode'] ?? data['damage_mode'] ?? data['damageMode'] ?? data['damage'] ?? '').toString().trim();
          final cause = (data['Root_Cause'] ?? data['root_cause'] ?? data['rootCause'] ?? data['cause'] ?? data['name'] ?? '').toString().trim();
          final isoCode = (data['ISO_14224_Code'] ?? data['iso_14224_code'] ?? data['isoCode'] ?? '').toString().trim();
          final severity = (data['Severity'] ?? data['severity'] ?? 'Major').toString().trim();
          final action = (data['Recommended_Action'] ?? data['recommended_action'] ?? data['recommendedAction'] ?? '').toString().trim();

          data['id'] = odcId;
          data['odcId'] = odcId;
          data['ODC_ID'] = odcId;
          data['discipline'] = discipline;
          data['Discipline'] = discipline;
          data['equipmentCategory'] = eqCategory;
          data['Equipment_Category'] = eqCategory;
          data['objectPart'] = objPart;
          data['Object_Part'] = objPart;
          data['damage'] = damage;
          data['damageMode'] = damage;
          data['Damage_Mode'] = damage;
          data['cause'] = cause;
          data['rootCause'] = cause;
          data['Root_Cause'] = cause;
          data['name'] = cause.isNotEmpty ? cause : objPart;
          data['category'] = discipline;
          data['isoCode'] = isoCode;
          data['ISO_14224_Code'] = isoCode;
          data['severity'] = severity;
          data['Severity'] = severity;
          data['recommendedAction'] = action;
          data['Recommended_Action'] = action;
          data['plantId'] = data['plantId'] ?? _userPlantId ?? 'GLOBAL';
          data['unitId'] = data['unitId'] ?? _userUnitId ?? 'GLOBAL';
          data['Plant_ID'] = data['plantId'];
          data['Unit_ID'] = data['unitId'];
          odcList.add(data);
        }
      }

      if (locList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${locList.length} Areas...');
        await _firestoreService.batchSave('locations', locList);
      }
      if (prList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${prList.length} Panel Rooms...');
        await _firestoreService.batchSave('panel_rooms', prList);
      }
      if (pnlList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${pnlList.length} Panels...');
        await _firestoreService.batchSave('panels', pnlList);
      }
      if (fdrList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${fdrList.length} Feeders...');
        await _firestoreService.batchSave('feeders', fdrList);
      }
      if (trList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${trList.length} Transformers...');
        await _firestoreService.batchSave('transformers', trList);
      }
      if (meList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${meList.length} Master Equipment...');
        await _firestoreService.batchSave('master_equipments', meList);
      }
      if (ftList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${ftList.length} Fault Types...');
        await _firestoreService.batchSave('fault_types', ftList);
      }
      if (odcList.isNotEmpty) {
        if (mounted) setState(() => _statusMessage = 'Uploading ${odcList.length} ODC Causes...');
        await _firestoreService.batchSave('odc', odcList);
      }

      final summary = [
        if (locList.isNotEmpty) '${locList.length} Areas',
        if (prList.isNotEmpty) '${prList.length} Rooms',
        if (pnlList.isNotEmpty) '${pnlList.length} Panels',
        if (fdrList.isNotEmpty) '${fdrList.length} Feeders',
        if (trList.isNotEmpty) '${trList.length} Transformers',
        if (meList.isNotEmpty) '${meList.length} Machines',
        if (ftList.isNotEmpty) '${ftList.length} Fault Types',
        if (odcList.isNotEmpty) '${odcList.length} ODC Causes',
      ].join(', ');

      if (mounted) {
        setState(() {
          _statusMessage = "Success! Uploaded $summary.";
          _previewData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import complete: $summary'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Upload failed: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructions = _getInstructions();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: CustomAppBar(title: 'Import ${widget.title}'),
      body: AnimatedGradientBackground(
        child: Column(
          children: [
            // 1. SCOPE SELECTOR (Exact Lux Level Checklist Style)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GlassContainer(
                borderRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _plants.contains(_userPlantId) ? _userPlantId : (_plants.isNotEmpty ? _plants.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Select Plant', border: InputBorder.none),
                              items: _plants.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: _isPlantLocked
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _userPlantId = val;
                                          _updateUnitList();
                                          _selectedLocationId = null;
                                          _selectedPanelId = null;
                                          _previewData.clear();
                                        });
                                        _loadHierarchyData();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _units.contains(_userUnitId) ? _userUnitId : (_units.isNotEmpty ? _units.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Select Unit', border: InputBorder.none),
                              items: _units.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: _isUnitLocked
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _userUnitId = val;
                                          _selectedLocationId = null;
                                          _selectedPanelId = null;
                                          _previewData.clear();
                                        });
                                        _loadHierarchyData();
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      if (['panels', 'feeders', 'master_equipments'].contains(widget.collectionId) && _locations.isNotEmpty) ...[
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _locations.any((l) => l.id == _selectedLocationId) ? _selectedLocationId : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: widget.collectionId == 'panels' ? 'Select Panel Room (Target)' : 'Select Location (Target)',
                                  border: InputBorder.none,
                                ),
                                items: _locations.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => _onLocationChanged(v),
                              ),
                            ),
                            if (widget.collectionId == 'master_equipments' && _panels.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _panels.any((p) => p.id == _selectedPanelId) ? _selectedPanelId : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Select Panel (Target)', border: InputBorder.none),
                                  items: _panels.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedPanelId = v),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. FORMAT GUIDE
                    GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("FORMAT GUIDE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                TextButton.icon(
                                  onPressed: _downloadTemplate,
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Choose Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Required Columns:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Text(instructions['Cols']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                            const SizedBox(height: 12),
                            Text("Instructions:", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Text(instructions['Note']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. FILE PICKER
                    GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text("Select Excel File (.xlsx)"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                elevation: 0,
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            if (_fileName != null) ...[
                              const SizedBox(height: 12),
                              Text("Selected: $_fileName", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                            ],
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _statusMessage!.startsWith('Error') || _statusMessage!.startsWith('Upload failed')
                                      ? Colors.redAccent
                                      : _statusMessage!.startsWith('Success')
                                          ? AppColors.success
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. PREVIEW TABLE & UPLOAD
                    if (_previewData.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Preview Records (${_previewData.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            "${_previewData.where((r) => r['Validation'] == 'OK').length} Ready / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Warning') == true).length} Warnings / ${_previewData.where((r) => r['Validation']?.toString().startsWith('Error') == true).length} Errors",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Collection Filter Chips
                      () {
                        const collLabels = {
                          'all': 'All',
                          'locations': 'Locations',
                          'panel_rooms': 'Panel Rooms',
                          'panels': 'Panels',
                          'feeders': 'Feeders',
                          'transformers': 'Transformers',
                          'master_equipments': 'Master Equipment',
                          'fault_types': 'Fault Types',
                          'odc': 'ODC Causes',
                          'odc_causes': 'ODC Causes',
                        };

                        final availableColls = ['all'];
                        for (final key in ['locations', 'panel_rooms', 'panels', 'feeders', 'transformers', 'master_equipments', 'fault_types', 'odc', 'odc_causes']) {
                          if (_previewData.any((r) => r['_collection'] == key)) {
                            availableColls.add(key);
                          }
                        }

                        if (availableColls.length <= 1) return const SizedBox.shrink();

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableColls.map((key) {
                              final count = key == 'all'
                                  ? _previewData.length
                                  : _previewData.where((r) => r['_collection'] == key).length;
                              final isSelected = _selectedPreviewTab == key;
                              final label = '${collLabels[key] ?? key} ($count)';

                              return Padding(
                                padding: const EdgeInsets.only(right: 8, bottom: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Theme.of(context).cardColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedPreviewTab = key);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }(),
                      const SizedBox(height: 8),

                      // Filtered Collection Table
                      () {
                        final displayedRows = _selectedPreviewTab == 'all'
                            ? _previewData
                            : _previewData.where((r) => r['_collection'] == _selectedPreviewTab).toList();

                        List<String> previewCols;
                        if (_selectedPreviewTab == 'locations' || widget.collectionId == 'locations') {
                          previewCols = ['Validation', 'id', 'name', 'description', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'panel_rooms' || widget.collectionId == 'panel_rooms') {
                          previewCols = ['Validation', 'id', 'name', 'description', 'locationId', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'panels' || widget.collectionId == 'panels') {
                          previewCols = ['Validation', 'id', 'name', 'type', 'description', 'panelRoomId', 'voltageLevel', 'busSections', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'feeders' || widget.collectionId == 'feeders') {
                          previewCols = ['Validation', 'id', 'name', 'type', 'description', 'panelId', 'busSection', 'operatingState', 'upstreamFeederId', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'transformers' || widget.collectionId == 'transformers') {
                          previewCols = ['Validation', 'id', 'name', 'windingType', 'ratingKva', 'primaryVoltage', 'secondaryVoltage', 'tertiaryVoltage', 'primarySourceFeederId', 'secondaryTargetPanelId', 'locationId', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'master_equipments' || widget.collectionId == 'master_equipments') {
                          previewCols = ['Validation', 'id', 'name', 'type', 'description', 'locationId', 'panelRoomId', 'panelId', 'feederId', 'plantId', 'unitId'];
                        } else if (_selectedPreviewTab == 'fault_types' || widget.collectionId == 'fault_types') {
                          final allRowKeys = <String>{};
                          for (final row in displayedRows) {
                            allRowKeys.addAll(row.keys.map((k) => k.toString()));
                          }
                          allRowKeys.remove('_sheetName');
                          allRowKeys.remove('_collection');
                          allRowKeys.remove('Validation');

                          final preferredOrder = [
                            'Fault_Code', 'faultCode', 'id',
                            'Fault_Name', 'faultName', 'name',
                            'Discipline', 'discipline', 'category',
                            'Target_Equipment', 'targetEquipment', 'equipmentType',
                            'Default_Severity', 'severity',
                            'Target_SLA_Hours', 'targetSlaHours',
                            'Diagnostic_Checks', 'diagnosticChecks',
                            'Corrective_Action', 'correctiveAction',
                            'Plant_ID', 'plantId',
                            'Unit_ID', 'unitId',
                          ];
                          final orderedCols = <String>[];
                          for (final col in preferredOrder) {
                            if (allRowKeys.remove(col)) orderedCols.add(col);
                          }
                          orderedCols.addAll(allRowKeys);
                          previewCols = ['Validation', ...orderedCols];
                        } else if (_selectedPreviewTab == 'odc' || _selectedPreviewTab == 'odc_causes' || widget.collectionId == 'odc' || widget.collectionId == 'odc_causes') {
                          final allRowKeys = <String>{};
                          for (final row in displayedRows) {
                            allRowKeys.addAll(row.keys.map((k) => k.toString()));
                          }
                          allRowKeys.remove('_sheetName');
                          allRowKeys.remove('_collection');
                          allRowKeys.remove('Validation');

                          final preferredOrder = [
                            'ODC_ID', 'odcId', 'id',
                            'Discipline', 'discipline', 'category',
                            'Equipment_Category', 'equipmentCategory',
                            'Object_Part', 'objectPart',
                            'Damage_Mode', 'damageMode', 'damage',
                            'Root_Cause', 'rootCause', 'cause', 'name',
                            'ISO_14224_Code', 'isoCode',
                            'Severity', 'severity',
                            'Recommended_Action', 'recommendedAction',
                            'Plant_ID', 'plantId',
                            'Unit_ID', 'unitId',
                          ];
                          final orderedCols = <String>[];
                          for (final col in preferredOrder) {
                            if (allRowKeys.remove(col)) orderedCols.add(col);
                          }
                          orderedCols.addAll(allRowKeys);
                          previewCols = ['Validation', ...orderedCols];
                        } else {
                          final allKeys = <String>{};
                          for (final row in displayedRows) {
                            allKeys.addAll(row.keys.map((k) => k.toString()));
                          }
                          previewCols = allKeys.where((k) => k != '_sheetName' && k != '_collection').toList();
                          if (previewCols.contains('Validation')) {
                            previewCols.remove('Validation');
                            previewCols.insert(0, 'Validation');
                          }
                        }

                        final activeCols = previewCols.where((col) {
                          if (col == 'Validation') return true;
                          return displayedRows.any((r) => r.containsKey(col));
                        }).toList();

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: GlassContainer(
                            borderRadius: 12,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 40,
                                headingRowColor: WidgetStateProperty.all(
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                ),
                                dataRowColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
                                  }
                                  return Colors.transparent;
                                }),
                                columns: activeCols.map((k) => DataColumn(
                                  label: Text(
                                    k == '_collection' ? 'Collection' : k,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                )).toList(),
                                rows: displayedRows.take(100).map((r) {
                                  return DataRow(
                                    cells: activeCols.map((colKey) {
                                      final val = r[colKey]?.toString() ?? '';
                                      final isValidation = colKey == 'Validation';
                                      Color? txtColor;
                                      if (isValidation) {
                                        if (val.startsWith('Error')) {
                                          txtColor = Colors.redAccent;
                                        } else if (val.startsWith('Warning') || val.startsWith('Will')) {
                                          txtColor = Colors.orangeAccent;
                                        } else if (val == 'OK') {
                                          txtColor = Colors.greenAccent;
                                        }
                                      }
                                      return DataCell(
                                        Text(
                                          val,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: txtColor ?? Theme.of(context).colorScheme.onSurface,
                                            fontWeight: isValidation ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      }(),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Confirm & Import All", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
